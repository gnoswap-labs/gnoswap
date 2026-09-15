package staker

import (
	"errors"
	"math"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gov/staker"
	pf "gno.land/r/gnoswap/protocol_fee"
)

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the authorized store write.
//   - period: new undelegation lockup period in seconds.
func (g *govStakerV1) setUnDelegationLockupPeriod(_ int, rlm realm, period int64) {
	if err := g.store.SetUnDelegationLockupPeriod(0, rlm, period); err != nil {
		panic(err)
	}
}

// nextDelegationID generates and returns the next unique delegation ID.
//
// Returns:
//   - int64: next available delegation ID
func (g *govStakerV1) nextDelegationID() int64 {
	counter := g.store.GetDelegationCounter()

	return counter.Next()
}

// getDelegation retrieves a delegation by its ID.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//
// Returns:
//   - *Delegation: delegation instance or nil if not found
func (g *govStakerV1) getDelegation(delegationID int64) *staker.Delegation {
	delegation, exists := g.store.GetDelegation(delegationID)
	if !exists {
		return nil
	}
	return delegation
}

// setDelegation stores or updates a delegation in the storage tree.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the authorized store write.
//   - delegationID: unique identifier of the delegation to store.
//   - delegation: delegation instance to store.
//
// Returns:
//   - error: nil on success, otherwise the storage write error.
func (g *govStakerV1) setDelegation(_ int, rlm realm, delegationID int64, delegation *staker.Delegation) error {
	return g.store.SetDelegation(0, rlm, delegationID, delegation)
}

// addDelegation adds a new delegation to storage and updates the delegation manager.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for delegation and manager writes.
//   - delegationID: unique identifier of the delegation to add.
//   - delegation: delegation instance whose delegator/delegatee pair is indexed.
//
// Returns:
//   - error: nil on success; otherwise the delegation or manager storage error.
func (g *govStakerV1) addDelegation(_ int, rlm realm, delegationID int64, delegation *staker.Delegation) error {
	if err := g.setDelegation(0, rlm, delegationID, delegation); err != nil {
		return err
	}

	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return g.store.SetDelegationManager(0, rlm, delegationManager)
}

// removeDelegation removes a delegation from storage and updates the delegation manager.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for delegation and manager writes.
//   - delegationID: unique identifier of the delegation to remove.
//
// Returns:
//   - error: nil on success; an error when the delegation is absent or a storage
//     write fails.
func (g *govStakerV1) removeDelegation(_ int, rlm realm, delegationID int64) error {
	delegation := g.getDelegation(delegationID)
	if delegation == nil {
		return errors.New(errDelegationNotFound)
	}

	if err := g.store.RemoveDelegation(0, rlm, delegationID); err != nil {
		return err
	}

	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return g.store.SetDelegationManager(0, rlm, delegationManager)
}

// getUserDelegations retrieves all delegations for a specific user.
//
// Parameters:
//   - user: user's address
//
// Returns:
//   - *bptree.BPTree: tree of user's delegations
func (g *govStakerV1) getUserDelegations(user address) *bptree.BPTree {
	delegationManager := g.store.GetDelegationManager()

	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return staker.NewUserDelegationTree()
	}

	return userDelegations
}

// getUserDelegationsWithDelegatee retrieves all delegations from a user to a specific delegatee.
//
// Parameters:
//   - user: user's address
//   - delegatee: delegatee's address
//
// Returns:
//   - []int64: list of user's delegation IDs to the delegatee
func (g *govStakerV1) getUserDelegationIDsWithDelegatee(user address, delegatee address) []int64 {
	delegationManager := g.store.GetDelegationManager()

	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return nil
	}

	delegateeStr := delegatee.String()
	delegationIDs := userDelegations.Get(delegateeStr)
	if delegationIDs == nil {
		return nil
	}

	ids, ok := delegationIDs.([]int64)
	if !ok {
		return nil
	}

	return ids
}

// addDelegationRecord records a delegation change in the history.
// Updates both total and user delegation histories with cumulative values.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for history writes.
//   - delegateeAddr: address of the delegatee whose user history changes.
//   - amount: delegation amount change, positive for delegation and negative for
//     undelegation.
//   - timestamp: Unix timestamp of the delegation change.
func (g *govStakerV1) addDelegationRecord(_ int, rlm realm, delegateeAddr address, amount int64, timestamp int64) {
	// Update total delegation history
	g.updateTotalDelegationHistory(0, rlm, amount, timestamp)

	// Update user delegation history
	g.updateUserDelegationHistory(0, rlm, delegateeAddr, amount, timestamp)
}

// updateTotalDelegationHistory updates the total delegation history with cumulative value.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the history write.
//   - amount: total delegation change, positive for delegation and negative for
//     undelegation.
//   - timestamp: Unix timestamp at which the cumulative value is stored.
func (g *govStakerV1) updateTotalDelegationHistory(_ int, rlm realm, amount int64, timestamp int64) {
	history := g.store.GetTotalDelegationHistory()

	// Get current total from the most recent entry
	currentTotal := g.getLatestTotalDelegation(history)
	newTotal := gnsmath.SafeAddInt64(currentTotal, amount)

	if newTotal < 0 {
		newTotal = 0
	}

	history.Set(timestamp, newTotal)

	if err := g.store.SetTotalDelegationHistory(0, rlm, history); err != nil {
		panic(err)
	}
}

// updateUserDelegationHistory updates the user delegation history with cumulative values.
// Structure: single BPTree keyed by composite key "addrStr|paddedTimestamp" -> int64
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the history write.
//   - delegateeAddr: address whose delegation history is updated.
//   - amount: delegation amount change, positive for delegation and negative for
//     undelegation.
//   - timestamp: Unix timestamp at which the cumulative value is stored.
func (g *govStakerV1) updateUserDelegationHistory(_ int, rlm realm, delegateeAddr address, amount int64, timestamp int64) {
	history := g.store.GetUserDelegationHistory()
	addrStr := delegateeAddr.String()

	// Get current amount from the most recent entry for this user
	currentAmount := g.getLatestUserDelegationByAddress(history, addrStr)
	newAmount := gnsmath.SafeAddInt64(currentAmount, amount)
	if newAmount < 0 {
		newAmount = 0
	}

	// Store new cumulative value under composite key
	history.Set(makeUserHistoryKey(addrStr, timestamp), newAmount)

	if err := g.store.SetUserDelegationHistory(0, rlm, history); err != nil {
		panic(err)
	}
}

// getLatestTotalDelegation gets the latest total delegation amount from history.
//
// Parameters:
//   - history: timestamp-keyed delegation history to inspect.
//
// Returns:
//   - int64: most recent cumulative total, or zero when history is empty.
func (g *govStakerV1) getLatestTotalDelegation(history *staker.UintTree) int64 {
	if history.Size() == 0 {
		return 0
	}

	latestTotal := int64(0)

	history.ReverseIterate(0, math.MaxInt64, func(key int64, value any) bool {
		totalInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid total type: %T", value))
		}

		latestTotal = totalInt

		return true // stop after first (most recent) entry
	})

	return latestTotal
}

// getLatestUserDelegationByAddress gets the latest delegation amount for a user
// from the composite-keyed user delegation history.
//
// Parameters:
//   - history: composite-keyed user delegation history to inspect.
//   - addrStr: string form of the user address whose latest amount is requested.
//
// Returns:
//   - int64: most recent cumulative amount for addrStr, or zero when none exists.
func (g *govStakerV1) getLatestUserDelegationByAddress(history *bptree.BPTree, addrStr string) int64 {
	lo, hi := userHistoryKeyRange(addrStr)

	latestAmount := int64(0)

	history.ReverseIterate(lo, hi, func(_ string, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		latestAmount = amountInt

		return true // stop after first (most recent) entry
	})

	return latestAmount
}

// addStakeEmissionReward adds stake to emission reward tracking for an address.
// This method updates the emission reward distribution state and adds stake for
// the specified address.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the reward-manager store write.
//   - address: reward-state identifier receiving the stake.
//   - amount: stake amount to add.
//   - currentTimestamp: Unix timestamp at which the stake is added.
//
// Returns:
//   - error: nil on success; an error from reward-state calculation or storage.
func (g *govStakerV1) addStakeEmissionReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.addStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager)
	if err != nil {
		return err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

	return nil
}

// removeStakeEmissionReward removes stake from emission reward tracking for an
// address. This method updates the emission reward distribution state.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the reward-manager store write.
//   - address: reward-state identifier whose stake is reduced.
//   - amount: stake amount to remove.
//   - currentTimestamp: Unix timestamp at which the stake is removed.
//
// Returns:
//   - error: nil on success; an error when the amount is invalid, exceeds stake,
//     or reward-manager storage fails.
func (g *govStakerV1) removeStakeEmissionReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.removeStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	if err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager); err != nil {
		return err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

	return nil
}

// claimRewardsEmissionReward claims emission rewards for an address.
// This method updates the emission reward distribution state and processes reward
// claiming.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the reward-manager store write.
//   - address: reward-state identifier whose emission rewards are claimed.
//   - currentTimestamp: Unix timestamp used to settle the reward state.
//
// Returns:
//   - int64: amount of emission rewards claimed.
//   - error: nil on success; an error from reward calculation or storage.
func (g *govStakerV1) claimRewardsEmissionReward(_ int, rlm realm, address string, currentTimestamp int64) (int64, error) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return 0, err
	}

	amount, err := resolvedManager.claimRewards(address, currentTimestamp)
	if err != nil {
		return 0, err
	}

	if err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager); err != nil {
		return 0, err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

	return amount, nil
}

// removeLaunchpadProjectDeposit removes a launchpad project deposit record.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - bool: true if successfully removed
func (g *govStakerV1) removeLaunchpadProjectDeposit(ownerAddress string) bool {
	launchpadProjectDeposits := g.store.GetLaunchpadProjectDeposits()
	return launchpadProjectDeposits.RemoveDeposit(ownerAddress)
}

// addStakeProtocolFeeReward records a stake increase for protocol fee rewards.
//
// The change only opens a new accrual epoch and appends one stake event, so its
// cost does not depend on how many tokens collected fees.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for protocol-fee cross calls and
//     manager storage writes.
//   - address: reward-state identifier receiving the stake.
//   - amount: positive stake amount to add.
//   - currentTimestamp: Unix timestamp recorded on the manager.
//
// Returns:
//   - error: nil on success; an error when the amount or manager storage update
//     is rejected.
func (g *govStakerV1) addStakeProtocolFeeReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	epoch := pf.AdvanceAccrualEpoch(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.addStake(address, amount, epoch); err != nil {
		return err
	}
	resolvedManager.SetAccumulatedTimestamp(currentTimestamp)

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return err
	}

	emitUpdateProtocolFeeStakeAccrual(protocolFeeRewardManager)

	return nil
}

// removeStakeProtocolFeeReward records a stake decrease for protocol fee rewards.
// Like addStakeProtocolFeeReward it never folds fees, so a withdrawal never pays
// for the reward calculation; that happens on collect, one token at a time if need be.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for protocol-fee cross calls and
//     manager storage writes.
//   - address: reward-state identifier whose stake is reduced.
//   - amount: non-negative stake amount to remove.
//   - currentTimestamp: Unix timestamp recorded on the manager.
//
// Returns:
//   - error: nil on success; an error when the amount or manager storage update
//     is rejected.
func (g *govStakerV1) removeStakeProtocolFeeReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	epoch := pf.AdvanceAccrualEpoch(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.removeStake(address, amount, epoch); err != nil {
		return err
	}
	resolvedManager.SetAccumulatedTimestamp(currentTimestamp)

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return err
	}

	emitUpdateProtocolFeeStakeAccrual(protocolFeeRewardManager)

	return nil
}

// foldProtocolFeeAccrual consumes up to limit pending accrual buckets of tokenPath
// from the protocol fee realm and folds them into the token's accumulator. A limit
// of zero or less consumes every pending bucket.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used with cross(rlm) for protocol-fee
//     bucket consumption and for manager storage access.
//   - resolvedManager: protocol-fee reward manager being updated.
//   - tokenPath: token identifier whose pending accrual buckets are folded.
//   - limit: positive maximum number of buckets to consume; zero or negative
//     consumes all pending buckets.
//   - currentTimestamp: Unix timestamp recorded after applying the buckets.
//
// Returns:
//   - error: nil on success; an error from applying the consumed accrual buckets.
func (g *govStakerV1) foldProtocolFeeAccrual(_ int, rlm realm, resolvedManager *ProtocolFeeRewardManagerResolver, tokenPath string, limit int, currentTimestamp int64) error {
	epochs, amounts := pf.ConsumeAccrualBuckets(cross(rlm), tokenPath, limit)
	exhausted := limit <= 0 || len(epochs) < limit

	return resolvedManager.applyAccrualBuckets(tokenPath, epochs, amounts, exhausted, currentTimestamp)
}

// claimRewardsProtocolFeeReward claims protocol fee rewards for an address in
// every token.
// It folds every pending token first, so its cost grows with the number of tokens
// that collected a fee. claimRewardProtocolFeeRewardByTokenPath is the bounded path.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used with cross(rlm) for distribution
//     and protocol-fee bucket consumption.
//   - address: reward-state identifier claiming rewards.
//   - currentTimestamp: Unix timestamp used to settle reward state.
//
// Returns:
//   - map[string]int64: protocol fee rewards claimed, keyed by token path.
//   - error: nil on success; an error from accrual folding, reward settlement, or
//     manager storage.
func (g *govStakerV1) claimRewardsProtocolFeeReward(_ int, rlm realm, address string, currentTimestamp int64) (map[string]int64, error) {
	// Claiming pays out of gov/staker's own balance, so the reserved fees are pulled in
	// from the protocol fee realm first.
	pf.DistributeProtocolFee(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	// Every pending token is consumed from the protocol fee realm. A known token with
	// nothing pending has no bucket in any epoch since its last fold, so an empty
	// exhaustive fold is enough to mark every closed epoch as settled for it.
	pendingTokenPaths := pf.GetAccrualPendingTokens()
	pending := make(map[string]bool, len(pendingTokenPaths))
	for _, tokenPath := range pendingTokenPaths {
		pending[tokenPath] = true
		if err := g.foldProtocolFeeAccrual(0, rlm, resolvedManager, tokenPath, 0, currentTimestamp); err != nil {
			return nil, err
		}
	}

	foldedTokenPaths := pendingTokenPaths
	for _, tokenPath := range protocolFeeRewardManager.GetTokenPaths() {
		if pending[tokenPath] {
			continue
		}
		if err := resolvedManager.applyAccrualBuckets(tokenPath, []int64{}, []int64{}, true, currentTimestamp); err != nil {
			return nil, err
		}
		foldedTokenPaths = append(foldedTokenPaths, tokenPath)
	}

	rewards, err := resolvedManager.claimRewards(address, currentTimestamp)
	if err != nil {
		return nil, err
	}

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return nil, err
	}

	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, foldedTokenPaths)

	return rewards, nil
}

// claimRewardProtocolFeeRewardByTokenPath claims one protocol fee reward token
// for an address.
//
// Both the fold and the settlement are bounded per call (maxAccrualBucketsPerCollect,
// maxStakeEventsPerCollect); a token with more pending work pays what is settled and
// keeps the rest for a later collect.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used with cross(rlm) for distribution
//     and manager storage access.
//   - address: reward-state identifier claiming the token reward.
//   - tokenPath: token identifier whose reward is collected.
//   - currentTimestamp: Unix timestamp used to settle reward state.
//
// Returns:
//   - int64: whole-token protocol fee reward settled in this call.
//   - error: nil on success; an error from bucket folding, settlement, or storage.
func (g *govStakerV1) claimRewardProtocolFeeRewardByTokenPath(_ int, rlm realm, address string, tokenPath string, currentTimestamp int64) (int64, error) {
	pf.DistributeProtocolFeeByTokenPath(cross(rlm), tokenPath)

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := g.foldProtocolFeeAccrual(0, rlm, resolvedManager, tokenPath, maxAccrualBucketsPerCollect, currentTimestamp); err != nil {
		return 0, err
	}

	reward, err := resolvedManager.claimTokenReward(address, tokenPath, maxStakeEventsPerCollect)
	if err != nil {
		return 0, err
	}

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return 0, err
	}

	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, []string{tokenPath})

	return reward, nil
}

// getClaimableProtocolFeeRewards reports what collecting every token would pay
// for a reward ID right now, pending accrual buckets included, without changing
// any state.
//
// Parameters:
//   - rewardID: emission/protocol-fee reward state identifier to inspect.
//
// Returns:
//   - map[string]int64: projected whole-token rewards keyed by token path.
//   - error: nil on success; an error when a token's projected reward cannot be
//     calculated.
func (g *govStakerV1) getClaimableProtocolFeeRewards(rewardID string) (map[string]int64, error) {
	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	rewards := make(map[string]int64)
	tokenPaths := protocolFeeRewardManager.GetTokenPaths()
	for _, tokenPath := range pf.GetAccrualPendingTokens() {
		if _, ok := protocolFeeRewardManager.GetTokenAccumulator(tokenPath); !ok {
			tokenPaths = append(tokenPaths, tokenPath)
		}
	}

	for _, tokenPath := range tokenPaths {
		pendingEpochs, pendingAmounts := pf.GetAccrualBuckets(tokenPath, 0)
		reward, err := resolvedManager.GetClaimableRewardAmount(rewardID, tokenPath, pendingEpochs, pendingAmounts)
		if err != nil {
			return nil, err
		}
		rewards[tokenPath] = reward
	}

	return rewards, nil
}

// getLaunchpadProjectDeposit retrieves the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - int64: deposit amount
//   - bool: true if project exists, false otherwise
func (g *govStakerV1) getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	launchpadDeposits := g.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
	return resolvedDeposits.getLaunchpadProjectDeposit(ownerAddress)
}

// setLaunchpadProjectDeposit sets the deposit amount for a launchpad project.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for the authorized store write.
//   - ownerAddress: project owner/reward identifier whose deposit is set.
//   - deposit: new deposit amount to store.
//
// Returns:
//   - error: nil on success, otherwise the storage write error.
func (g *govStakerV1) setLaunchpadProjectDeposit(_ int, rlm realm, ownerAddress string, deposit int64) error {
	launchpadDeposits := g.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
	resolvedDeposits.setLaunchpadProjectDeposit(ownerAddress, deposit)

	return g.store.SetLaunchpadProjectDeposits(0, rlm, launchpadDeposits)
}

// addStakeFromLaunchpad adds stake for a launchpad project and updates reward
// tracking. This method creates a special reward ID and manages its deposit.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for reward-manager and deposit
//     storage writes.
//   - address: launchpad project wallet address.
//   - amount: stake amount to add to the project.
//   - currentTimestamp: Unix timestamp used for reward accounting.
//
// Returns:
//   - error: nil on success; an error from emission/protocol reward updates or
//     deposit storage.
func (g *govStakerV1) addStakeFromLaunchpad(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.addStakeEmissionReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.addStakeProtocolFeeReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit = gnsmath.SafeAddInt64(deposit, amount)
	if err := g.setLaunchpadProjectDeposit(0, rlm, launchpadRewardID, deposit); err != nil {
		return err
	}

	return nil
}

// removeStakeFromLaunchpad removes stake for a launchpad project and updates
// reward tracking. This method manages its deposit and clamps it at zero.
//
// Parameters:
//   - _: Noncrossing helper-call discriminator; pass 0.
//   - rlm: propagated staker realm context used for reward-manager and deposit
//     storage writes.
//   - address: launchpad project wallet address.
//   - amount: stake amount to remove from the project.
//   - currentTimestamp: Unix timestamp used for reward accounting.
//
// Returns:
//   - error: nil on success; an error from emission/protocol reward updates or
//     deposit storage.
func (g *govStakerV1) removeStakeFromLaunchpad(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.removeStakeEmissionReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.removeStakeProtocolFeeReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit = gnsmath.SafeSubInt64(deposit, amount)
	if deposit < 0 {
		deposit = 0
	}

	if err := g.setLaunchpadProjectDeposit(0, rlm, launchpadRewardID, deposit); err != nil {
		return err
	}

	return nil
}

// makeLaunchpadRewardID creates a special reward identifier for launchpad projects.
// This ensures launchpad project rewards are tracked separately from regular user stakes.
//
// Parameters:
//   - address: project wallet address
//
// Returns:
//   - string: formatted launchpad reward ID
func (g *govStakerV1) makeLaunchpadRewardID(address string) string {
	return "launchpad:" + address
}
