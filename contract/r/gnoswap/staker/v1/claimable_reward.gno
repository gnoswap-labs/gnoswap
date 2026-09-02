package staker

import (
	"chain"
	"chain/runtime"
	"time"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

// claimableRewardKeySeparator separates the receiver address from the token path in a
// ledger key. Neither an address nor a token path can contain it, so a key round-trips
// unambiguously and a receiver's entries form a contiguous key range.
const claimableRewardKeySeparator = "\x00"

// claimableRewardRangeEnd terminates a receiver's key range. Iterate treats end as
// exclusive, and "\x01" is the smallest string that sorts after every key prefixed with
// the receiver plus the separator.
const claimableRewardRangeEnd = "\x01"

// ClaimableRewards is the ledger of settled-but-not-yet-paid reward amounts, keyed by
// (receiver, token path).
//
// Reward settlement credits this ledger instead of transferring tokens, so the accounting
// half of a collect can never be blocked by the payout half. Payout drains the ledger in a
// separate step (CollectReward's tail, or ClaimRewards), and anything that cannot be paid
// right now stays here until it can.
type ClaimableRewards struct {
	tree *bptree.BPTree
}

// NewClaimableRewards creates an empty claimable reward ledger.
func NewClaimableRewards() *ClaimableRewards {
	return &ClaimableRewards{
		tree: sr.NewBPTreeN(16), // receiver|tokenPath -> int64
	}
}

// claimableRewardEntry is one ledger row.
type claimableRewardEntry struct {
	tokenPath string
	amount    int64
}

// claimableRewardKey builds the ledger key for a (receiver, token path) pair.
func claimableRewardKey(receiver address, tokenPath string) string {
	return receiver.String() + claimableRewardKeySeparator + tokenPath
}

// get returns the amount currently claimable by receiver for tokenPath.
func (self *ClaimableRewards) get(receiver address, tokenPath string) int64 {
	value := self.tree.Get(claimableRewardKey(receiver, tokenPath))
	if value == nil {
		return 0
	}

	amount, ok := value.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast claimable reward to int64: %T", value))
	}

	return amount
}

// add credits amount to the receiver's balance for tokenPath. Non-positive amounts are
// ignored so the ledger only ever holds payable rows.
func (self *ClaimableRewards) add(receiver address, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	self.tree.Set(
		claimableRewardKey(receiver, tokenPath),
		gnsmath.SafeAddInt64(self.get(receiver, tokenPath), amount),
	)
}

// remove clears the receiver's balance for tokenPath.
func (self *ClaimableRewards) remove(receiver address, tokenPath string) {
	self.tree.Remove(claimableRewardKey(receiver, tokenPath))
}

// entriesOf returns every ledger row belonging to receiver.
//
// The rows are materialized before they are returned because callers remove them while
// paying out, and mutating the tree mid-iteration is not safe.
func (self *ClaimableRewards) entriesOf(receiver address) []claimableRewardEntry {
	entries := make([]claimableRewardEntry, 0)

	prefix := receiver.String() + claimableRewardKeySeparator
	self.tree.Iterate(prefix, receiver.String()+claimableRewardRangeEnd, func(key string, value any) bool {
		amount, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast claimable reward to int64: %T", value))
		}

		entries = append(entries, claimableRewardEntry{
			tokenPath: key[len(prefix):],
			amount:    amount,
		})

		return false
	})

	return entries
}

// getClaimableRewards returns the claimable reward ledger backed by the store.
func (s *stakerV1) getClaimableRewards() *ClaimableRewards {
	return &ClaimableRewards{
		tree: s.store.GetClaimableRewards(),
	}
}

// creditClaimableReward records amount as owed to receiver in tokenPath, without moving
// any tokens.
func (s *stakerV1) creditClaimableReward(receiver address, tokenPath string, amount int64) {
	s.getClaimableRewards().add(receiver, tokenPath, amount)
}

// payoutClaimableRewards drains the receiver's ledger rows and transfers them out.
//
// Every token is handled independently and best-effort: a token the staker realm cannot
// currently cover is left in the ledger (and reported through an event) rather than
// aborting the whole payout, so one short or misbehaving reward token cannot strand the
// rest. Pending protocol fees for the token are forwarded first, but only when the
// balance covers both, so fee forwarding can never eat into what the receiver is owed.
//
// Returns the amount actually paid per token path.
func (s *stakerV1) payoutClaimableRewards(_ int, rlm realm, receiver address) map[string]int64 {
	paid := make(map[string]int64)

	claimable := s.getClaimableRewards()
	entries := claimable.entriesOf(receiver)
	if len(entries) == 0 {
		return paid
	}

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	previousRealm := rlm.Previous()

	for _, entry := range entries {
		if entry.amount <= 0 {
			claimable.remove(receiver, entry.tokenPath)
			continue
		}

		balance := common.BalanceOf(entry.tokenPath, stakerAddr)
		if balance < entry.amount {
			chain.Emit(
				"InsufficientClaimableReward",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"receiver", receiver.String(),
				"tokenPath", entry.tokenPath,
				"claimableAmount", utils.FormatInt(entry.amount),
				"availableAmount", utils.FormatInt(balance),
				"currentTime", utils.FormatInt(time.Now().Unix()),
				"currentHeight", utils.FormatInt(runtime.ChainHeight()),
			)

			continue
		}

		// Effects before interactions: the row is cleared before anything leaves this
		// realm, so a re-entrant claim cannot see it twice.
		claimable.remove(receiver, entry.tokenPath)

		pendingProtocolFee := s.store.GetPendingProtocolFees()[entry.tokenPath]
		if pendingProtocolFee > 0 && balance >= gnsmath.SafeAddInt64(pendingProtocolFee, entry.amount) {
			s.settleProtocolFee(0, rlm, entry.tokenPath, 0)
		}

		common.SafeGRC20Transfer(0, rlm, entry.tokenPath, receiver, entry.amount)

		paid[entry.tokenPath] = entry.amount

		chain.Emit(
			"ClaimReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"receiver", receiver.String(),
			"tokenPath", entry.tokenPath,
			"amount", utils.FormatInt(entry.amount),
			"currentTime", utils.FormatInt(time.Now().Unix()),
			"currentHeight", utils.FormatInt(runtime.ChainHeight()),
		)
	}

	return paid
}

// ClaimRewards pays out every reward the caller has already had settled.
//
// Rewards are settled into the claimable ledger by CollectReward and by UnStakeToken; this
// is the withdrawal half. It carries no dependency on a staked position, so a position can
// be unstaked first and its rewards claimed later.
//
// Returns the amount paid per token path.
func (s *stakerV1) ClaimRewards(_ int, rlm realm) map[string]int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	en.MintAndDistributeGns(cross(rlm))

	return s.payoutClaimableRewards(0, rlm, rlm.Previous().Address())
}

// ClaimRewardsFor pays out receiver's settled rewards to receiver.
//
// Permissionless by design: the funds can only ever reach the ledger owner, and an open
// entry point is what lets the community pool's share (internal penalties and unclaimable
// rewards) be flushed after an unstake-only flow.
//
// Returns the amount paid per token path.
func (s *stakerV1) ClaimRewardsFor(_ int, rlm realm, receiver address) map[string]int64 {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	en.MintAndDistributeGns(cross(rlm))

	return s.payoutClaimableRewards(0, rlm, receiver)
}

// GetClaimableRewardsOf returns every settled-but-unpaid reward amount of receiver, keyed
// by token path.
func (s *stakerV1) GetClaimableRewardsOf(receiver address) map[string]int64 {
	rewards := make(map[string]int64)
	for _, entry := range s.getClaimableRewards().entriesOf(receiver) {
		rewards[entry.tokenPath] = entry.amount
	}

	return rewards
}

// GetClaimableReward returns receiver's settled-but-unpaid amount for a single token.
func (s *stakerV1) GetClaimableReward(receiver address, tokenPath string) int64 {
	return s.getClaimableRewards().get(receiver, tokenPath)
}
