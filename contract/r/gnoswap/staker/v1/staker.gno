package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"

	"gno.land/r/gnoswap/gns"

	en "gno.land/r/gnoswap/emission"
	pn "gno.land/r/gnoswap/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/referral"
)

const ZERO_ADDRESS = address("")

var (
	adminAddr         = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	devOpsAddr        = access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	communityPoolAddr = access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	stakerAddr        = access.MustGetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr     = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	protocolFeeAddr   = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	positionAddr      = access.MustGetAddress(prbac.ROLE_POSITION.String())
)

// Deposits manages all staked positions.
type Deposits struct {
	tree *avl.Tree
}

// NewDeposits creates a new Deposits instance.
func NewDeposits() *Deposits {
	return &Deposits{
		tree: avl.NewTree(), // positionId -> *Deposit
	}
}

// Has checks if a position ID exists in deposits.
func (self *Deposits) Has(positionId uint64) bool {
	return self.tree.Has(EncodeUint(positionId))
}

// Iterate traverses deposits within the specified range.
func (self *Deposits) Iterate(start uint64, end uint64, fn func(positionId uint64, deposit *sr.Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(positionId string, depositI any) bool {
		dpst := retrieveDeposit(depositI)
		return fn(DecodeUint(positionId), dpst)
	})
}

func (self *Deposits) IterateByPoolPath(start, end uint64, poolPath string, fn func(positionId uint64, deposit *sr.Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(positionId string, depositI any) bool {
		deposit := retrieveDeposit(depositI)
		if deposit.TargetPoolPath() != poolPath {
			return false
		}

		return fn(DecodeUint(positionId), deposit)
	})
}

// Size returns the number of deposits.
func (self *Deposits) Size() int {
	return self.tree.Size()
}

// get retrieves a deposit by position ID.
func (self *Deposits) get(positionId uint64) *sr.Deposit {
	depositI, ok := self.tree.Get(EncodeUint(positionId))
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}
	return retrieveDeposit(depositI)
}

// retrieveDeposit safely casts data to Deposit type.
func retrieveDeposit(data any) *sr.Deposit {
	deposit, ok := data.(*sr.Deposit)
	if !ok {
		panic("failed to cast value to *Deposit")
	}
	return deposit
}

// set stores a deposit for a position ID.
func (self *Deposits) set(positionId uint64, deposit *sr.Deposit) {
	self.tree.Set(EncodeUint(positionId), deposit)
}

// remove deletes a deposit by position ID.
func (self *Deposits) remove(positionId uint64) {
	self.tree.Remove(EncodeUint(positionId))
}

// ExternalIncentives manages external incentive programs.
type ExternalIncentives struct {
	tree *avl.Tree
}

// NewExternalIncentives creates a new ExternalIncentives instance.
func NewExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: avl.NewTree(),
	}
}

// Has checks if an incentive ID exists.
func (self *ExternalIncentives) Has(incentiveId string) bool { return self.tree.Has(incentiveId) }

// Size returns the number of external incentives.
func (self *ExternalIncentives) Size() int { return self.tree.Size() }

// get retrieves an external incentive by ID.
func (self *ExternalIncentives) get(incentiveId string) *sr.ExternalIncentive {
	incentiveI, ok := self.tree.Get(incentiveId)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentiveId(%s) not found", incentiveId),
		))
	}

	incentive, ok := incentiveI.(*sr.ExternalIncentive)
	if !ok {
		panic("failed to cast value to *ExternalIncentive")
	}
	return incentive
}

// set stores an external incentive.
func (self *ExternalIncentives) set(incentiveId string, incentive *sr.ExternalIncentive) {
	self.tree.Set(incentiveId, incentive)
}

// remove deletes an external incentive by ID.
func (self *ExternalIncentives) remove(incentiveId string) {
	self.tree.Remove(incentiveId)
}

// Stakers manages deposits by staker address.
type Stakers struct {
	tree *avl.Tree // address -> depositId -> *Deposit
}

// NewStakers creates a new Stakers instance.
func NewStakers() *Stakers {
	return &Stakers{
		tree: avl.NewTree(),
	}
}

// IterateAll traverses all deposits for a specific address.
func (self *Stakers) IterateAll(address address, fn func(depositId uint64, deposit *sr.Deposit) bool) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}
	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Iterate("", "", func(depositId string, depositI any) bool {
		deposit, ok := depositI.(*sr.Deposit)
		if !ok {
			panic("failed to cast value to *Deposit")
		}
		return fn(DecodeUint(depositId), deposit)
	})
}

// addDeposit adds a deposit for a staker address.
func (self *Stakers) addDeposit(address address, depositId uint64, deposit *sr.Deposit) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		depositTree := avl.NewTree()
		self.tree.Set(address.String(), depositTree)
		depositTreeI = depositTree
	}

	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Set(EncodeUint(depositId), deposit)
}

// removeDeposit removes a deposit for a staker address.
func (self *Stakers) removeDeposit(address address, depositId uint64) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}

	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Remove(EncodeUint(depositId))
}

// retrieveDepositTree safely casts data to AVL tree type.
func retrieveDepositTree(data any) *avl.Tree {
	depositTree, ok := data.(*avl.Tree)
	if !ok {
		panic("failed to cast depositTree to *avl.Tree")
	}
	return depositTree
}

// emissionCacheUpdateHook creates a hook function that updates the emission cache when called.
// This follows the same pattern as other hooks in the staker contract.
func (s *stakerV1) emissionCacheUpdateHook(emissionAmountPerSecond int64) {
	poolTier := s.getPoolTier()
	if poolTier != nil {
		currentTime := time.Now().Unix()
		currentHeight := runtime.ChainHeight()
		pools := s.getPools()

		// First cache the current rewards before updating emission
		poolTier.cacheReward(currentHeight, currentTime, pools)

		// Update the current emission cache with the latest value
		poolTier.currentEmission = emissionAmountPerSecond

		// Now apply the new emission rate to each pool individually
		poolTier.applyCacheToAllPools(pools, currentTime, emissionAmountPerSecond)

		s.updatePoolTier(poolTier)
	}
}

// StakeToken stakes an LP position NFT to earn rewards.
//
// Transfers position NFT to staker and begins reward accumulation.
// Eligible for internal incentives (GNS emission) and external rewards.
// Position must have liquidity and be in eligible pool tier.
//
// Parameters:
//   - positionId: LP position NFT token ID to stake
//   - referrer: Optional referral address for tracking
//
// Returns:
//   - poolPath: Pool identifier (token0:token1:fee)
//
// Requirements:
//   - Caller must own the position NFT
//   - Position must have active liquidity
//   - Pool must be in tier 1, 2, or 3
//   - Position not already staked
//
// Note: Out-of-range positions earn no rewards but can be staked.
func (s *stakerV1) StakeToken(positionId uint64, referrer string) string {
	halt.AssertIsNotHaltedStaker()

	assertIsNotStaked(s, positionId)

	en.MintAndDistributeGns(cross)

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	owner := s.nftAccessor.MustOwnerOf(positionIdFrom(positionId))
	currentTime := time.Now().Unix()

	actualReferrer := referrer
	if !referral.TryRegister(cross, caller, referrer) {
		actualReferrer = referral.GetReferral(caller.String())
	}

	if err := hasTokenOwnership(owner, caller); err != nil {
		panic(err.Error())
	}

	if err := tokenHasLiquidity(positionId); err != nil {
		panic(err.Error())
	}

	// check pool path from positionId
	poolPath := pn.GetPositionPoolKey(positionId)
	pools := s.getPools()

	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errNonIncentivizedPool,
			ufmt.Sprintf("cannot stake position to non existing pool(%s)", poolPath),
		))
	}

	err := s.poolHasIncentives(pool)
	if err != nil {
		panic(err.Error())
	}

	liquidity := getLiquidity(positionId)
	tickLower, tickUpper := getTickOf(positionId)

	warmups := s.store.GetWarmupTemplate()
	currentWarmups := instantiateWarmup(warmups, currentTime)

	// staked status
	deposit := sr.NewDeposit(
		caller,
		poolPath,
		liquidity,
		currentTime,
		tickLower,
		tickUpper,
		currentWarmups,
	)

	// when staking, add new created incentives to deposit
	currentIncentiveIds := s.getExternalIncentiveIdsBy(poolPath, 0, currentTime)

	for _, incentiveId := range currentIncentiveIds {
		incentive := s.getExternalIncentives().get(incentiveId)
		// If incentive is ended, not available to collect reward
		if currentTime > incentive.EndTimestamp() {
			continue
		}

		deposit.AddExternalIncentiveId(incentiveId)
	}

	// set last external incentive ids updated at
	deposit.SetLastExternalIncentiveUpdatedAt(currentTime)

	deposits := s.getDeposits()
	deposits.set(positionId, deposit)

	s.getStakers().addDeposit(caller, positionId, deposit)

	// transfer NFT ownership to staker contract
	if err := s.transferDeposit(positionId, owner, caller, stakerAddr); err != nil {
		panic(err.Error())
	}

	// after transfer, set caller(user) as position operator (to collect fee and reward)
	pn.SetPositionOperator(cross, positionId, caller)

	poolTier := s.getPoolTier()
	poolTier.cacheReward(runtime.ChainHeight(), currentTime, pools)
	s.updatePoolTier(poolTier)

	signedLiquidity := i256.FromUint256(liquidity)
	currentTick := s.poolAccessor.GetSlot0Tick(poolPath)

	poolResolver := NewPoolResolver(pool)

	isInRange := false
	if pn.IsInRange(positionId) {
		isInRange = true
		poolResolver.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}
	// historical tick must be set regardless of the deposit's range
	poolResolver.HistoricalTick().Set(currentTime, currentTick)

	// This could happen because of how position stores the ticks.
	// Ticks are negated if the token1 < token0.
	poolResolver.TickResolver(tickUpper).modifyDepositUpper(currentTime, signedLiquidity)
	poolResolver.TickResolver(tickLower).modifyDepositLower(currentTime, signedLiquidity)
	s.getPools().set(poolPath, pool)

	amount0, amount1 := s.calculateAmounts(poolPath, tickLower, tickUpper, liquidity)

	chain.Emit(
		"StakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", poolPath,
		"liquidity", liquidity.ToString(),
		"positionUpperTick", formatAnyInt(tickUpper),
		"positionLowerTick", formatAnyInt(tickLower),
		"currentTick", formatAnyInt(currentTick),
		"isInRange", formatBool(isInRange),
		"referrer", actualReferrer,
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
	)

	return poolPath
}

// transferDeposit transfers deposit ownership to a new address.
//
// Manages NFT custody during staking operations.
// Transfers ownership to staker contract for reward eligibility.
// Handles special cases for mint-and-stake operations.
//
// Parameters:
//   - positionId: The ID of the position NFT to transfer
//   - owner: The current owner of the position
//   - caller: The entity initiating the transfer
//   - to: The recipient address (usually staker contract)
//
// Security Features:
//   - Prevents self-transfer exploits
//   - Validates ownership before transfer
//   - Atomic operation with staking
//   - No transfer if owner == to (mint & stake case)
//
// Returns:
//   - nil: If owner and recipient are same (mint-and-stake)
//   - error: If caller unauthorized or transfer fails
//
// NFT remains locked in staker until unstaking.
// Otherwise delegates the transfer to `gnft.TransferFrom`.
func (s *stakerV1) transferDeposit(positionId uint64, owner, caller, to address) error {
	// if owner is the same as to, when mint and stake, it will be the same address
	if owner == to {
		return nil
	}

	if caller == to {
		return ufmt.Errorf(
			"%v: only owner(%s) can transfer positionId(%d), called from %s",
			errNoPermission, owner, positionId, caller,
		)
	}

	// transfer NFT ownership
	return s.nftAccessor.TransferFrom(owner, to, positionIdFrom(positionId))
}

// CollectReward harvests accumulated rewards for a staked position. This includes both
// internal GNS emission and external incentive rewards.
//
// State Transition:
//  1. Warm-up amounts are clears for both internal and external rewards
//  2. Reward tokens are transferred to the owner
//  3. Penalty fees are transferred to protocol/community addresses
//  4. GNS balance is recalculated
//
// Requirements:
//   - Contract must not be halted
//   - Caller must be the position owner
//   - Position must be staked (have a deposit record)
//
// Parameters:
// CollectReward claims accumulated rewards without unstaking.
//
// Parameters:
//   - positionId: LP position NFT token ID
//   - unwrapResult: if true, unwraps WUGNOT to GNOT
//
// Returns poolPath, gnsAmount, externalRewards map, externalPenalties map.
func (s *stakerV1) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	assertIsDepositor(s, caller, positionId)

	deposit := s.getDeposits().get(positionId)
	depositResolver := NewDepositResolver(deposit)

	en.MintAndDistributeGns(cross)

	currentTime := time.Now().Unix()
	blockHeight := runtime.ChainHeight()
	previousRealm := runtime.PreviousRealm()

	// get all internal and external rewards
	reward := s.calcPositionReward(blockHeight, currentTime, positionId)

	// transfer external rewards to user
	toUserExternalReward := make(map[string]int64)
	toUserExternalPenalty := make(map[string]int64)

	for incentiveId, rewardAmount := range reward.External {
		if rewardAmount == 0 && reward.ExternalPenalty[incentiveId] == 0 {
			continue
		}

		incentive := s.getExternalIncentives().get(incentiveId)
		if incentive == nil {
			// Incentive could be missing; skip to keep collection working.
			chain.Emit(
				"SkippedMissingIncentive",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"positionId", formatUint(positionId),
				"incentiveId", incentiveId,
				"currentTime", formatAnyInt(currentTime),
				"currentHeight", formatAnyInt(blockHeight),
			)
			continue
		}

		incentiveResolver := NewExternalIncentiveResolver(incentive)
		if !incentiveResolver.IsStarted(currentTime) {
			continue
		}

		if incentiveResolver.RewardAmount() < rewardAmount {
			// Do not update last collect time here; insufficient funds should
			// leave the incentive collectible when refilled or corrected.
			chain.Emit(
				"InsufficientExternalReward",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"positionId", formatUint(positionId),
				"incentiveId", incentiveId,
				"requiredAmount", formatAnyInt(rewardAmount),
				"availableAmount", formatAnyInt(incentiveResolver.RewardAmount()),
				"currentTime", formatAnyInt(currentTime),
				"currentHeight", formatAnyInt(blockHeight),
			)
			continue
		}

		// process external reward to user
		incentive.SetRewardAmount(safeSubInt64(incentive.RewardAmount(), rewardAmount))
		rewardToken := incentive.RewardToken()

		toUserExternalReward[rewardToken] = safeAddInt64(toUserExternalReward[rewardToken], rewardAmount)
		toUser, feeAmount, err := s.handleStakingRewardFee(rewardToken, rewardAmount, false)
		if err != nil {
			panic(err.Error())
		}

		// process external penalty
		externalPenalty := reward.ExternalPenalty[incentiveId]
		incentive.SetRewardAmount(safeSubInt64(incentive.RewardAmount(), externalPenalty))

		toUserExternalPenalty[rewardToken] = safeAddInt64(toUserExternalPenalty[rewardToken], externalPenalty)
		totalDistributedRewardAmount := safeAddInt64(rewardAmount, externalPenalty)
		depositResolver.addCollectedExternalReward(incentiveId, totalDistributedRewardAmount)
		incentiveResolver.addDistributedRewardAmount(totalDistributedRewardAmount)

		// Update the last collect time ONLY for this specific incentive
		// This happens only if the reward was successfully transferred.
		err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime)
		if err != nil {
			panic(err)
		}

		// If incentive ended and user already collected after end, remove from index
		// This ensures deposit's incentive list shrinks over time as incentives complete
		if depositResolver.ExternalRewardLastCollectTime(incentiveId) > incentiveResolver.EndTimestamp() {
			deposit.RemoveExternalIncentiveId(incentiveId)
		}

		// update
		s.getExternalIncentives().set(incentiveId, incentive)

		if externalPenalty > 0 {
			common.SafeGRC20Transfer(cross, rewardToken, communityPoolAddr, externalPenalty)
		}

		if toUser > 0 {
			if common.IsGNOTWrappedPath(rewardToken) && unwrapResult {
				tErr := unwrapWithTransfer(deposit.Owner(), toUser)
				if tErr != nil {
					panic(tErr)
				}
			} else {
				common.SafeGRC20Transfer(cross, rewardToken, deposit.Owner(), toUser)
			}
		}

		chain.Emit(
			"ProtocolFeeExternalReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"fromPositionId", formatUint(positionId),
			"fromPoolPath", incentive.TargetPoolPath(),
			"feeTokenPath", rewardToken,
			"feeAmount", formatAnyInt(feeAmount),
			"currentTime", formatAnyInt(currentTime),
			"currentHeight", formatAnyInt(blockHeight),
		)

		chain.Emit(
			"CollectReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"positionId", formatUint(positionId),
			"poolPath", deposit.TargetPoolPath(),
			"recipient", deposit.Owner().String(),
			"incentiveId", incentiveId,
			"rewardToken", rewardToken,
			"rewardAmount", formatAnyInt(rewardAmount),
			"rewardToUser", formatAnyInt(toUser),
			"rewardToFee", formatAnyInt(rewardAmount-toUser),
			"rewardPenalty", formatAnyInt(externalPenalty),
			"isRequestUnwrap", formatBool(unwrapResult),
			"currentTime", formatAnyInt(currentTime),
			"currentHeight", formatAnyInt(blockHeight),
		)
	}

	// internal reward to user
	toUser, feeAmount, err := s.handleStakingRewardFee(GNS_PATH, reward.Internal, true)
	if err != nil {
		panic(err.Error())
	}

	chain.Emit(
		"ProtocolFeeInternalReward",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"fromPositionId", formatUint(positionId),
		"fromPoolPath", deposit.TargetPoolPath(),
		"feeTokenPath", GNS_PATH,
		"feeAmount", formatAnyInt(feeAmount),
	)

	totalEmissionSent := s.store.GetTotalEmissionSent()

	if toUser > 0 {
		// internal reward to user
		totalEmissionSent = safeAddInt64(totalEmissionSent, toUser)
		depositResolver.addCollectedInternalReward(reward.Internal)
	}

	if reward.InternalPenalty > 0 {
		// internal penalty to community pool
		totalEmissionSent = safeAddInt64(totalEmissionSent, reward.InternalPenalty)
		depositResolver.addCollectedInternalReward(reward.InternalPenalty)
	}

	// Unclaimable must be processed after regular rewards so that accumulated
	// unclaimable amounts are reset in the same collect window.
	unClaimableInternal := s.processUnClaimableReward(depositResolver.TargetPoolPath(), currentTime)
	if unClaimableInternal > 0 {
		totalEmissionSent = safeAddInt64(totalEmissionSent, unClaimableInternal)
	}

	err = s.store.SetTotalEmissionSent(totalEmissionSent)
	if err != nil {
		panic(err)
	}

	// Update lastCollectTime for internal rewards (GNS emissions)
	err = depositResolver.updateInternalRewardLastCollectTime(currentTime)
	if err != nil {
		panic(err)
	}

	deposits := s.getDeposits()
	deposits.set(positionId, deposit)

	if toUser > 0 {
		gns.Transfer(cross, deposit.Owner(), toUser)
	}

	if reward.InternalPenalty > 0 {
		gns.Transfer(cross, communityPoolAddr, reward.InternalPenalty)
	}

	if unClaimableInternal > 0 {
		gns.Transfer(cross, communityPoolAddr, unClaimableInternal)
	}

	rewardToUser := formatAnyInt(toUser)
	rewardPenalty := formatAnyInt(reward.InternalPenalty)

	chain.Emit(
		"CollectReward",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", depositResolver.TargetPoolPath(),
		"recipient", depositResolver.Owner().String(),
		"rewardToken", GNS_PATH,
		"rewardAmount", formatAnyInt(reward.Internal),
		"rewardToUser", rewardToUser,
		"rewardToFee", formatAnyInt(reward.Internal-toUser),
		"rewardPenalty", rewardPenalty,
		"rewardUnClaimableAmount", formatAnyInt(unClaimableInternal),
		"currentTime", formatAnyInt(currentTime),
	)

	return rewardToUser, rewardPenalty, toUserExternalReward, toUserExternalPenalty
}

// UnStakeToken withdraws an LP token from staking, collecting all pending rewards
// and returning the token to its original owner.
//
// Parameters:
//   - positionId: LP position NFT token ID to unstake
//   - unwrapResult: Convert WUGNOT to GNOT if true
//
// Process:
//  1. Collects all pending rewards (GNS + external)
//  2. Transfers NFT ownership back to original owner
//  3. Clears position operator rights
//  4. Removes from reward tracking systems
//  5. Cleans up all staking metadata
//
// Returns:
//   - poolPath: Pool identifier where position was staked
//
// Requirements:
//   - Caller must be the depositor
//   - Position must be currently staked
func (s *stakerV1) UnStakeToken(positionId uint64, unwrapResult bool) string { // poolPath
	caller := runtime.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()
	assertIsDepositor(s, caller, positionId)

	deposit := s.getDeposits().get(positionId)

	// unStaked status
	poolPath := deposit.TargetPoolPath()

	// claim All Rewards
	s.CollectReward(positionId, unwrapResult)

	if err := s.applyUnStake(positionId); err != nil {
		panic(err)
	}

	// transfer NFT ownership to origin owner
	s.nftAccessor.TransferFrom(stakerAddr, deposit.Owner(), positionIdFrom(positionId))
	pn.SetPositionOperator(cross, positionId, ZERO_ADDRESS)

	// get position information for event
	liquidity := getLiquidity(positionId)
	tickLower, tickUpper := getTickOf(positionId)

	amount0, amount1 := s.calculateAmounts(poolPath, tickLower, tickUpper, liquidity)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"UnStakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", poolPath,
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"isRequestUnwrap", formatBool(unwrapResult),
		"from", stakerAddr.String(),
		"to", deposit.Owner().String(),
	)

	return poolPath
}

func (s *stakerV1) applyUnStake(positionId uint64) error {
	deposit := s.getDeposits().get(positionId)
	depositResolver := NewDepositResolver(deposit)
	pool, ok := s.getPools().Get(depositResolver.TargetPoolPath())
	poolResolver := NewPoolResolver(pool)
	if !ok {
		return ufmt.Errorf(
			"%v: pool(%s) does not exist",
			errDataNotFound, depositResolver.TargetPoolPath(),
		)
	}

	currentTime := time.Now().Unix()
	currentTick := s.poolAccessor.GetSlot0Tick(depositResolver.TargetPoolPath())
	signedLiquidity := i256.Zero().Neg(i256.FromUint256(depositResolver.Liquidity()))
	if pn.IsInRange(positionId) {
		poolResolver.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}

	upperTick := poolResolver.TickResolver(depositResolver.TickUpper())
	lowerTick := poolResolver.TickResolver(depositResolver.TickLower())
	upperTick.modifyDepositUpper(currentTime, signedLiquidity)
	lowerTick.modifyDepositLower(currentTime, signedLiquidity)

	s.getDeposits().remove(positionId)
	s.getStakers().removeDeposit(deposit.Owner(), positionId)

	owner := s.nftAccessor.MustOwnerOf(positionIdFrom(positionId))
	caller := runtime.PreviousRealm().Address()
	if err := hasTokenOwnership(owner, caller); err != nil {
		return err
	}

	return nil
}

// hasTokenOwnership validates that the caller has permission to operate the token.
func hasTokenOwnership(owner, caller address) error {
	isCallerOwner := owner == caller
	isStakerOwner := owner == stakerAddr

	if !isCallerOwner && !isStakerOwner {
		return errNoPermission
	}

	return nil
}

// poolHasIncentives checks if the pool has any stakeable incentives (internal or external).
// External incentive eligibility (active or within short future window) is handled inside IsExternallyIncentivizedPool.
func (s *stakerV1) poolHasIncentives(pool *sr.Pool) error {
	poolPath := pool.PoolPath()
	hasInternal := s.getPoolTier().IsInternallyIncentivizedPool(poolPath)
	hasExternal := NewPoolResolver(pool).IsExternallyIncentivizedPool()

	if !hasInternal && !hasExternal {
		return ufmt.Errorf(
			"%v: cannot stake position to non incentivized pool(%s)",
			errNonIncentivizedPool, poolPath,
		)
	}

	return nil
}

// tokenHasLiquidity checks if the target positionId has non-zero liquidity
func tokenHasLiquidity(positionId uint64) error {
	if getLiquidity(positionId).Lte(zeroUint256) {
		return ufmt.Errorf(
			"%v: positionId(%d) has no liquidity",
			errZeroLiquidity, positionId,
		)
	}
	return nil
}

func getLiquidity(positionId uint64) *u256.Uint {
	return u256.Zero().Set(pn.GetPositionLiquidity(positionId))
}

func getTickOf(positionId uint64) (int32, int32) {
	tickLower := pn.GetPositionTickLower(positionId)
	tickUpper := pn.GetPositionTickUpper(positionId)
	if tickUpper < tickLower {
		panic(ufmt.Sprintf("tickUpper(%d) is less than tickLower(%d)", tickUpper, tickLower))
	}
	return tickLower, tickUpper
}

// calculateAmounts calculates the amounts of token0 and token1 for a given liquidity and range.
func (s *stakerV1) calculateAmounts(poolPath string, tickLower, tickUpper int32, liquidity *u256.Uint) (*u256.Uint, *u256.Uint) {
	sqrtPriceX96 := s.poolAccessor.GetSlot0SqrtPriceX96(poolPath)
	sqrtPriceLowerX96 := common.TickMathGetSqrtRatioAtTick(tickLower)
	sqrtPriceUpperX96 := common.TickMathGetSqrtRatioAtTick(tickUpper)

	return common.GetAmountsForLiquidity(sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity)
}
