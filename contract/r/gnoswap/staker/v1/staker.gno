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

// Deposits manages all staked positions.
type Deposits struct {
	tree *bptree.BPTree
}

// NewDeposits creates a new Deposits instance.
func NewDeposits() *Deposits {
	return &Deposits{
		tree: sr.NewBPTreeN(16), // positionId -> *Deposit
	}
}

// Has checks if a position ID exists in deposits.
func (self *Deposits) Has(positionId uint64) bool {
	return self.tree.Has(utils.EncodeUint64(positionId))
}

// Iterate traverses deposits within the specified range.
func (self *Deposits) Iterate(start uint64, end uint64, fn func(positionId uint64, deposit *sr.Deposit) bool) {
	self.tree.Iterate(utils.EncodeUint64(start), utils.EncodeUint64(end), func(positionId string, depositI any) bool {
		dpst := retrieveDeposit(depositI)
		return fn(utils.DecodeUint64(positionId), dpst)
	})
}

func (self *Deposits) IterateByPoolPath(start, end uint64, poolPath string, fn func(positionId uint64, deposit *sr.Deposit) bool) {
	self.tree.Iterate(utils.EncodeUint64(start), utils.EncodeUint64(end), func(positionId string, depositI any) bool {
		deposit := retrieveDeposit(depositI)
		if deposit.TargetPoolPath() != poolPath {
			return false
		}

		return fn(utils.DecodeUint64(positionId), deposit)
	})
}

// Size returns the number of deposits.
func (self *Deposits) Size() int {
	return self.tree.Size()
}

// get retrieves a deposit by position ID.
func (self *Deposits) get(positionId uint64) *sr.Deposit {
	depositI := self.tree.Get(utils.EncodeUint64(positionId))
	if depositI == nil {
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
	self.tree.Set(utils.EncodeUint64(positionId), deposit)
}

// remove deletes a deposit by position ID.
func (self *Deposits) remove(positionId uint64) {
	self.tree.Remove(utils.EncodeUint64(positionId))
}

// ExternalIncentives manages external incentive programs.
type ExternalIncentives struct {
	tree *bptree.BPTree
}

// NewExternalIncentives creates a new ExternalIncentives instance.
func NewExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: sr.NewBPTreeN(16),
	}
}

// Has checks if an incentive ID exists.
func (self *ExternalIncentives) Has(incentiveId string) bool { return self.tree.Has(incentiveId) }

// Size returns the number of external incentives.
func (self *ExternalIncentives) Size() int { return self.tree.Size() }

// get retrieves an external incentive by ID.
func (self *ExternalIncentives) get(incentiveId string) *sr.ExternalIncentive {
	incentiveI := self.tree.Get(incentiveId)
	if incentiveI == nil {
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

// EmissionCacheUpdateHook updates the emission cache when called.
// This follows the same pattern as other hooks in the staker contract.
func (s *stakerV1) emissionCacheUpdateHook(_ int, rlm realm, emissionAmountPerSecond int64) {
	poolTier := s.getPoolTier()
	if poolTier != nil {
		currentTime := time.Now().Unix()
		pools := s.getPools()

		// First cache the current rewards before updating emission
		poolTier.cacheReward(currentTime, pools)

		// Update the current emission cache with the latest value
		poolTier.currentEmission = emissionAmountPerSecond

		// Now apply the new emission rate to each pool individually
		poolTier.applyCacheToAllPools(pools, currentTime, emissionAmountPerSecond)

		s.updatePoolTier(0, rlm, poolTier)
	}
}

// stakeScanLowerBound returns the lower bound of the stake-time incentive scan
// window, clamped to 0. The start-time index encodes keys as unsigned, so a
// negative bound aborts when the chain time is under TIMESTAMP_365DAYS.
func stakeScanLowerBound(currentTime int64) int64 {
	if currentTime < TIMESTAMP_365DAYS {
		return 0
	}

	return currentTime - TIMESTAMP_365DAYS
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
func (s *stakerV1) StakeToken(_ int, rlm realm, positionId uint64, referrer string) string {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	assertIsNotStaked(s, positionId)
	assertHasNoExitCheckpoint(s, positionId)

	en.MintAndDistributeGns(cross(rlm))

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	currentTime := time.Now().Unix()

	owner, err := s.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		panic(err.Error())
	}
	assertIsPositionOwner(owner, caller)

	actualReferrer := referral.TryRegister(cross(rlm), caller, referrer)

	if err := tokenHasLiquidity(positionId); err != nil {
		panic(err.Error())
	}

	// check pool path from positionId
	poolPath, err := pn.GetPositionPoolKey(positionId)
	if err != nil {
		panic(err)
	}
	pools := s.getPools()

	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errNonIncentivizedPool,
			ufmt.Sprintf("cannot stake position to non existing pool(%s)", poolPath),
		))
	}

	err = s.poolHasIncentives(pool)
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

	// when staking, add new incentives to deposit.
	//
	// Incentive duration is capped at TIMESTAMP_365DAYS, so anything still
	// active at currentTime starts within [currentTime-365d, currentTime].
	// Incentives starting before that window have ended and are filtered by
	// the EndTimestamp check below.
	//
	currentIncentiveIds := s.getExternalIncentiveIdsBy(poolPath, stakeScanLowerBound(currentTime), currentTime)

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

	// transfer NFT ownership to staker contract
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	if err := s.transferDeposit(0, rlm, positionId, owner, caller, stakerAddr); err != nil {
		panic(err.Error())
	}

	// after transfer, set caller(user) as position operator (to collect fee and reward)
	pn.SetPositionOperator(cross(rlm), positionId, caller)

	poolTier := s.getPoolTier()
	poolTier.cacheRewardForPool(currentTime, pools, poolPath)

	signedLiquidity := i256.FromUint256(liquidity)
	currentTick := s.poolAccessor.GetSlot0Tick(poolPath)

	poolResolver := NewPoolResolver(pool)

	isInRange := false
	inRange, err := pn.IsInRange(positionId)
	if err != nil {
		panic(err)
	}
	if inRange {
		isInRange = true
		poolResolver.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}
	// historical tick must be set regardless of the deposit's range
	if poolResolver.isChangedTick(currentTime, currentTick) {
		poolResolver.Pool.SetHistoricalTickAt(currentTime, currentTick)
	}

	// This could happen because of how position stores the ticks.
	// Ticks are negated if the token1 < token0.
	// A tick this stake creates must be seeded before it is persisted.
	upperTick := pool.Ticks().Get(tickUpper)
	if upperTick == nil {
		upperTick = sr.NewTick(tickUpper)
		poolResolver.initializeNewTickOutsideAccumulation(currentTime, currentTick, tickUpper, upperTick)
	}

	lowerTick := pool.Ticks().Get(tickLower)
	if lowerTick == nil {
		lowerTick = sr.NewTick(tickLower)
		poolResolver.initializeNewTickOutsideAccumulation(currentTime, currentTick, tickLower, lowerTick)
	}

	upperTickResolver := NewTickResolver(upperTick)
	lowerTickResolver := NewTickResolver(lowerTick)

	upperTickResolver.modifyDepositUpper(currentTime, signedLiquidity)
	lowerTickResolver.modifyDepositLower(currentTime, signedLiquidity)

	amount0, amount1 := s.calculateAmounts(poolPath, tickLower, tickUpper, liquidity)

	// Get accumulator values for reward calculation tracking
	globalAccX128, stakedLiquidity := poolResolver.globalRewardRatioAccumulationAt(currentTime)
	lowerOutsideAccX128 := lowerTickResolver.CurrentOutsideAccumulation(currentTime)
	upperOutsideAccX128 := upperTickResolver.CurrentOutsideAccumulation(currentTime)

	pool.Ticks().SetTick(tickUpper, upperTick)
	pool.Ticks().SetTick(tickLower, lowerTick)
	s.getPools().set(poolPath, pool)

	chain.Emit(
		"StakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", utils.FormatUint(positionId),
		"poolPath", poolPath,
		"owner", owner.String(),
		"liquidity", liquidity.ToString(),
		"positionUpperTick", utils.FormatInt(tickUpper),
		"positionLowerTick", utils.FormatInt(tickLower),
		"currentTick", utils.FormatInt(currentTick),
		"isInRange", utils.FormatBool(isInRange),
		"referrer", actualReferrer,
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"stakedLiquidity", stakedLiquidity.ToString(),
		"globalRewardRatioAccX128", globalAccX128.ToString(),
		"lowerTickOutsideAccX128", lowerOutsideAccX128.ToString(),
		"upperTickOutsideAccX128", upperOutsideAccX128.ToString(),
	)

	return poolPath
}

// transferDeposit transfers deposit ownership to a new address.
//
// Manages NFT custody during staking operations.
// Transfers ownership to staker contract for reward eligibility.
// Handles cases where the staker already holds custody.
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
//   - No transfer if owner == to (already in custody)
//
// Returns:
//   - nil: If owner and recipient are same
//   - error: If caller unauthorized or transfer fails
//
// NFT remains locked in staker until unstaking.
// Otherwise delegates the transfer to `gnft.TransferFrom`.
func (s *stakerV1) transferDeposit(_ int, rlm realm, positionId uint64, owner, caller, to address) error {
	// If the recipient already owns the NFT, no transfer is needed.
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
	return s.nftAccessor.TransferFrom(0, rlm, owner, to, positionIdFrom(positionId))
}

// collectContext carries the values every reward delivery of one collect call shares: the deposit being
// collected, the collect timestamp and height, the caller identity used in events, and the accumulator
// snapshot emitted with every collect event.
//
// Resolving it once is what keeps a collect-everything call at a single snapshot: the emission delivery
// and each incentive delivery all read the same context.
type collectContext struct {
	positionId      uint64
	deposit         *sr.Deposit
	depositResolver *DepositResolver

	// checkpoint is set when the position was unstaked before collecting.
	checkpoint *sr.UnstakedPosition

	currentTime int64
	blockHeight int64

	prevAddr  string
	prevRealm string

	stakedLiquidity     *u256.Uint
	globalAccX128       *u256.Uint
	lowerOutsideAccX128 *u256.Uint
	upperOutsideAccX128 *u256.Uint
}

// newCollectContext resolves the deposit and snapshots the accumulator values used for reward
// calculation tracking. Call it AFTER the calculation's state update has been applied, so a lazily
// created pool is already persisted.
func (s *stakerV1) newCollectContext(_ int, rlm realm, target *collectTarget, currentTime, blockHeight int64) *collectContext {
	positionId := target.positionId
	deposit := target.deposit

	pool, _ := s.getPools().Get(deposit.TargetPoolPath())
	poolResolver := newPoolResolverWithExit(pool, target.checkpoint)
	globalAccX128, stakedLiquidity := poolResolver.globalRewardRatioAccumulationAt(currentTime)

	lowerTickResolver := NewTickResolver(poolResolver.GetOrNewTick(deposit.TickLower()))
	upperTickResolver := NewTickResolver(poolResolver.GetOrNewTick(deposit.TickUpper()))

	previousRealm := rlm.Previous()

	return &collectContext{
		positionId:      positionId,
		deposit:         deposit,
		depositResolver: NewDepositResolver(deposit),
		checkpoint:      target.checkpoint,

		currentTime: currentTime,
		blockHeight: blockHeight,

		prevAddr:  previousRealm.Address().String(),
		prevRealm: previousRealm.PkgPath(),

		stakedLiquidity:     stakedLiquidity,
		globalAccX128:       globalAccX128,
		lowerOutsideAccX128: lowerTickResolver.CurrentOutsideAccumulation(currentTime),
		upperOutsideAccX128: upperTickResolver.CurrentOutsideAccumulation(currentTime),
	}
}

// persistDeposit writes the deposit back, unless it belongs to a checkpoint and is not there.
func (self *collectContext) persistDeposit(s *stakerV1) {
	if self.checkpoint != nil {
		return
	}

	s.getDeposits().set(self.positionId, self.deposit)
}

// markEmissionCollected records the emission collect on the checkpoint.
func (s *stakerV1) markEmissionCollected(target *collectTarget) {
	if !target.isCheckpoint() {
		return
	}

	target.checkpoint.MarkEmissionCollected()
	s.dropUnstakedPositionIfCollected(target)
}

// markIncentiveCollected records the incentive collect on the checkpoint. An incentive that
// could not be funded stays pending, the same way it stays collectible while staked; delivery
// reports that as an empty reward token against a non-zero amount.
func (s *stakerV1) markIncentiveCollected(_ int, rlm realm, target *collectTarget, incentiveId string, rewardAmount int64, rewardToken string) {
	if !target.isCheckpoint() || !target.checkpoint.HasPendingIncentiveId(incentiveId) {
		return
	}

	if rewardToken == "" && rewardAmount > 0 {
		return
	}

	target.checkpoint.MarkIncentiveCollected(incentiveId)

	// The pool's incentives become refundable again once no checkpoint owes one.
	if !target.checkpoint.HasPendingIncentives() {
		s.addUnsettledIncentiveCount(0, rlm, target.deposit.TargetPoolPath(), -1)
	}

	s.dropUnstakedPositionIfCollected(target)
}

// collectTarget is the record a collect runs against: the live deposit while staked, or the
// exit checkpoint an unstake left behind.
type collectTarget struct {
	positionId uint64
	deposit    *sr.Deposit
	// currentTime is now while staked, and the exit time for a checkpoint.
	currentTime int64
	checkpoint  *sr.UnstakedPosition
}

// checkpointDeposit returns the deposit to calculate against when it is not in the tree.
func (self *collectTarget) checkpointDeposit() *sr.Deposit {
	if self.checkpoint == nil {
		return nil
	}

	return self.deposit
}

// isCheckpoint reports whether the collect runs against an exit checkpoint.
func (self *collectTarget) isCheckpoint() bool {
	return self.checkpoint != nil
}

// resolveCollectTarget resolves what a collect runs against and asserts the caller may.
func (s *stakerV1) resolveCollectTarget(positionId uint64, caller address) *collectTarget {
	position := s.getUnstakedPositions().get(positionId)
	if position == nil {
		assertIsDepositor(s, caller, positionId)

		return &collectTarget{
			positionId:  positionId,
			deposit:     s.getDeposits().get(positionId),
			currentTime: time.Now().Unix(),
		}
	}

	// A checkpoint collect is permissionless: it can only ever deliver to the position's owner,
	// and an open entry point is what lets anyone clear the checkpoints that hold up
	// EndExternalIncentive on the pool.
	return &collectTarget{
		positionId:  positionId,
		deposit:     position.Deposit(),
		currentTime: position.ExitTime(),
		checkpoint:  position,
	}
}

// newRewardCollectParam builds the calculation input for a collect of the given position.
func (s *stakerV1) newRewardCollectParam(target *collectTarget, currentTime, blockHeight int64) *calculatePositionRewardParam {
	return &calculatePositionRewardParam{
		CurrentHeight: blockHeight,
		CurrentTime:   currentTime,
		Deposits:      s.getDeposits(),
		Pools:         s.getPools(),
		PoolTier:      s.getPoolTier(),
		PositionId:    target.positionId,
		Deposit:       target.checkpointDeposit(),
		Exit:          target.checkpoint,
	}
}

// CollectEmissionReward harvests only the GNS emission (internal) reward of a staked position.
//
// The emission and the external incentive rewards track their collection cursors independently
// (a single lastCollectTime on the deposit for emission, one per incentive id for external), so
// collecting one side leaves the other side fully accruable.
//
// State Transition:
//  1. Emission is minted and distributed so the staker holds the GNS to pay out
//  2. Warm-up ratios are applied and the emission reward is split into user / penalty amounts
//  3. GNS is transferred to the owner, penalties and unclaimable amounts to the community pool
//  4. The deposit's internal lastCollectTime is advanced
//
// Requirements:
//   - Contract must not be halted
//   - Caller must be the position owner
//   - Position must be staked (have a deposit record)
//
// Parameters:
//   - positionId: LP position NFT token ID
//
// Returns the GNS amount sent to the user and the penalty amount sent to the community pool.
func (s *stakerV1) CollectEmissionReward(_ int, rlm realm, positionId uint64) (int64, int64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	target := s.resolveCollectTarget(positionId, rlm.Previous().Address())

	en.MintAndDistributeGns(cross(rlm))

	currentTime := target.currentTime
	blockHeight := runtime.ChainHeight()

	// Calculation is read-only; the resulting state updates (reward-cache update, lazy pool persistence)
	// are applied via updateInternalPositionReward, which is the collect-only counterpart to the
	// calculation shared with the Collectable* view getters.
	rewardParam := s.newRewardCollectParam(target, currentTime, blockHeight)
	rewards, rewardUpdate, err := s.calculateInternalPositionReward(rewardParam)
	if err != nil {
		panic(err)
	}
	reward := aggregateRewards(rewards)
	s.updateInternalPositionReward(rewardParam, rewardUpdate)

	ctx := s.newCollectContext(0, rlm, target, currentTime, blockHeight)

	rewardToUser, rewardPenalty := s.deliverEmissionReward(0, rlm, ctx, reward)

	s.markEmissionCollected(target)

	return rewardToUser, rewardPenalty
}

// CollectExternalIncentiveReward harvests one external incentive reward of a staked position.
//
// Each incentive keeps its own lastCollectTime, so the emission reward and every incentive other than
// the requested one stay collectible afterwards. The requested incentive is itself left collectible when
// it cannot be delivered (not started, zero reward, or underfunded).
//
// State Transition:
//  1. Incentives created since the deposit's last update are added to its incentive index
//  2. Warm-up ratios are applied and the reward is split into user / penalty amounts
//  3. The reward token is transferred to the owner, the penalty accumulates on the incentive
//  4. The collected incentive's lastCollectTime is advanced
//
// Requirements:
//   - Contract must not be halted
//   - Caller must be the position owner
//   - Position must be staked (have a deposit record)
//   - Incentive must exist and target the pool the position is staked in
//
// Parameters:
//   - positionId: LP position NFT token ID
//   - incentiveId: external incentive to collect
//
// Returns the collected reward amount, before the staking reward fee is taken, and the penalty amount
// kept by the incentive.
func (s *stakerV1) CollectExternalIncentiveReward(_ int, rlm realm, positionId uint64, incentiveId string) (int64, int64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	target := s.resolveCollectTarget(positionId, rlm.Previous().Address())
	assertIsIncentiveOfPool(s, target.deposit.TargetPoolPath(), positionId, incentiveId)

	currentTime := target.currentTime
	blockHeight := runtime.ChainHeight()

	// Calculation is read-only; the resulting state updates (lazy pool persistence, deposit
	// incentive-index updates) are applied via updateExternalPositionReward, which is the collect-only
	// counterpart to the calculation shared with the Collectable* view getters.
	rewardParam := s.newRewardCollectParam(target, currentTime, blockHeight)
	rewards, rewardUpdate := s.calculateExternalPositionReward(rewardParam, incentiveId)
	reward := aggregateRewards(rewards)
	s.updateExternalPositionReward(rewardParam, rewardUpdate)

	ctx := s.newCollectContext(0, rlm, target, currentTime, blockHeight)

	rewardToken, rewardAmount, rewardPenalty := s.deliverExternalIncentiveReward(
		0, rlm, ctx, incentiveId, reward.External[incentiveId], reward.ExternalPenalty[incentiveId],
	)

	// Persist the deposit even when nothing was delivered: the incentive-index update above still ran.
	ctx.persistDeposit(s)

	s.markIncentiveCollected(0, rlm, target, incentiveId, reward.External[incentiveId], rewardToken)

	return rewardAmount, rewardPenalty
}

// CollectReward harvests accumulated rewards for a staked position. This includes both
// internal GNS emission and external incentive rewards.
//
// It is the "collect everything" entry point kept for callers that do not want to choose a side. It
// calculates both sides in one pass and delivers each incentive, then the emission reward, through the
// same delivery functions the single-source entry points use.
//
// Requirements:
//   - Contract must not be halted
//   - Caller must be the position owner
//   - Position must be staked (have a deposit record)
//
// Parameters:
//   - positionId: LP position NFT token ID
//
// Returns the GNS amount sent to the user, the GNS penalty amount, and the per-token external
// reward and penalty amounts.
func (s *stakerV1) CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedWithdraw()

	target := s.resolveCollectTarget(positionId, rlm.Previous().Address())

	en.MintAndDistributeGns(cross(rlm))

	currentTime := target.currentTime
	blockHeight := runtime.ChainHeight()

	// One calculation and one state update cover both reward sources.
	rewardParam := s.newRewardCollectParam(target, currentTime, blockHeight)
	rewards, rewardUpdate, err := s.calculatePositionReward(rewardParam)
	if err != nil {
		panic(err)
	}
	reward := aggregateRewards(rewards)
	s.updatePositionReward(rewardParam, rewardUpdate)

	ctx := s.newCollectContext(0, rlm, target, currentTime, blockHeight)

	// External rewards are delivered first, the order the two reward paths ran in before they were split.
	toUserExternalReward := make(map[string]int64)
	toUserExternalPenalty := make(map[string]int64)

	for _, incentiveId := range rewardUpdate.externalIncentiveIds {
		rewardToken, rewardAmount, rewardPenalty := s.deliverExternalIncentiveReward(
			0, rlm, ctx, incentiveId, reward.External[incentiveId], reward.ExternalPenalty[incentiveId],
		)

		s.markIncentiveCollected(0, rlm, target, incentiveId, reward.External[incentiveId], rewardToken)

		// An empty reward token means the incentive delivered nothing and stays collectible.
		if rewardToken == "" {
			continue
		}

		toUserExternalReward[rewardToken] = gnsmath.SafeAddInt64(toUserExternalReward[rewardToken], rewardAmount)
		toUserExternalPenalty[rewardToken] = gnsmath.SafeAddInt64(toUserExternalPenalty[rewardToken], rewardPenalty)
	}

	internalRewardToUser, internalRewardPenalty := s.deliverEmissionReward(0, rlm, ctx, reward)

	s.markEmissionCollected(target)

	return utils.FormatInt(internalRewardToUser), utils.FormatInt(internalRewardPenalty), toUserExternalReward, toUserExternalPenalty
}

// deliverExternalIncentiveReward pays out one incentive's already-calculated reward: it debits the
// incentive, advances its lastCollectTime, takes the staking reward fee and transfers the rest.
//
// The incentive is skipped WITHOUT advancing its lastCollectTime when it yields no user reward or does
// not hold enough reward token, so the amount stays collectible later. A skipped incentive is reported
// by an empty reward token.
//
// A warmup ratio below 100% floors the user reward, so a small accrual can yield rewardAmount == 0 while
// externalPenalty > 0. Such a call is skipped as a whole: the penalty is NOT booked and the cursor is NOT
// advanced, which leaves the untouched accrual to be recalculated over the wider window of the next
// collect. Nothing is lost either way, because an unbooked penalty stays in the incentive's reward
// amount, and endExternalIncentive refunds the reward amount and the accumulated penalty to the same
// address.
//
// Returns the reward token, the collected reward amount before the staking reward fee, and the penalty.
func (s *stakerV1) deliverExternalIncentiveReward(
	_ int,
	rlm realm,
	ctx *collectContext,
	incentiveId string,
	rewardAmount int64,
	externalPenalty int64,
) (string, int64, int64) {
	// Skip when user reward is zero.
	// Do not update last collect time so the reward accrues until
	// the next collection where a non-zero amount can be delivered.
	if rewardAmount == 0 {
		return "", 0, 0
	}

	// get panics on a missing id; incentives are never removed from the tree.
	incentive := s.getExternalIncentives().get(incentiveId)

	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// Defensive backstop, unreachable through the current callers: computeExternalReward already drops a
	// not-yet-started incentive at the same currentTime, so its reward is zero and the check above
	// returns first. Kept so a future caller that supplies a non-zero amount cannot pay out of an
	// incentive whose distribution window has not opened.
	if !incentiveResolver.IsStarted(ctx.currentTime) {
		return "", 0, 0
	}

	totalRewardAmount := gnsmath.SafeAddInt64(rewardAmount, externalPenalty)

	if incentiveResolver.RewardAmount() < totalRewardAmount {
		// Do not update last collect time here; insufficient funds should
		// leave the incentive collectible when refilled or corrected.
		chain.Emit(
			"InsufficientExternalReward",
			"prevAddr", ctx.prevAddr,
			"prevRealm", ctx.prevRealm,
			"positionId", utils.FormatUint(ctx.positionId),
			"incentiveId", incentiveId,
			"requiredAmount", utils.FormatInt(totalRewardAmount),
			"availableAmount", utils.FormatInt(incentiveResolver.RewardAmount()),
			"currentTime", utils.FormatInt(ctx.currentTime),
			"currentHeight", utils.FormatInt(ctx.blockHeight),
		)

		return "", 0, 0
	}

	// process reward states
	rewardToken := incentive.RewardToken()

	incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), totalRewardAmount))
	incentiveResolver.addDistributedRewardAmount(rewardAmount)
	incentiveResolver.addAccumulatedPenaltyAmount(externalPenalty)
	ctx.depositResolver.addCollectedExternalReward(incentiveId, totalRewardAmount)

	// Update the last collect time ONLY for this specific incentive
	// This happens only if the reward was successfully transferred.
	err := ctx.depositResolver.updateExternalRewardLastCollectTime(incentiveId, ctx.currentTime)
	if err != nil {
		panic(err)
	}

	// If incentive ended and user already collected after end, remove from index
	// This ensures deposit's incentive list shrinks over time as incentives complete
	if ctx.depositResolver.ExternalRewardLastCollectTime(incentiveId) > incentiveResolver.EndTimestamp() {
		ctx.deposit.RemoveExternalIncentiveId(incentiveId)
	}

	// update
	s.getExternalIncentives().set(incentiveId, incentive)

	toUser, feeAmount, err := s.handleStakingRewardFee(0, rlm, rewardToken, rewardAmount, false)
	if err != nil {
		panic(err.Error())
	}

	if toUser > 0 {
		common.SafeGRC20Transfer(0, rlm, rewardToken, ctx.deposit.Owner(), toUser)
	}

	chain.Emit(
		"ProtocolFeeExternalReward",
		"prevAddr", ctx.prevAddr,
		"prevRealm", ctx.prevRealm,
		"fromPositionId", utils.FormatUint(ctx.positionId),
		"fromPoolPath", incentive.TargetPoolPath(),
		"feeTokenPath", rewardToken,
		"feeAmount", utils.FormatInt(feeAmount),
		"currentTime", utils.FormatInt(ctx.currentTime),
		"currentHeight", utils.FormatInt(ctx.blockHeight),
	)

	chain.Emit(
		"CollectReward",
		"prevAddr", ctx.prevAddr,
		"prevRealm", ctx.prevRealm,
		"positionId", utils.FormatUint(ctx.positionId),
		"poolPath", ctx.deposit.TargetPoolPath(),
		"recipient", ctx.deposit.Owner().String(),
		"incentiveId", incentiveId,
		"rewardToken", rewardToken,
		"rewardAmount", utils.FormatInt(rewardAmount),
		"rewardToUser", utils.FormatInt(toUser),
		"rewardToFee", utils.FormatInt(rewardAmount-toUser),
		"rewardPenalty", utils.FormatInt(externalPenalty),
		"currentTime", utils.FormatInt(ctx.currentTime),
		"currentHeight", utils.FormatInt(ctx.blockHeight),
		"stakedLiquidity", ctx.stakedLiquidity.ToString(),
		"globalRewardRatioAccX128", ctx.globalAccX128.ToString(),
		"lowerTickOutsideAccX128", ctx.lowerOutsideAccX128.ToString(),
		"upperTickOutsideAccX128", ctx.upperOutsideAccX128.ToString(),
	)

	return rewardToken, rewardAmount, externalPenalty
}

// deliverEmissionReward pays out the already-calculated GNS emission reward: it takes the staking reward
// fee, settles the pool's unclaimable accumulation to the community pool, advances totalEmissionSent and
// the deposit's internal lastCollectTime, and transfers the GNS.
//
// When the position has no emission reward to deliver, the internal lastCollectTime is left untouched so
// the amount keeps accruing; the pool's unclaimable accumulation is still settled.
//
// Returns the GNS amount sent to the user and the penalty amount sent to the community pool.
func (s *stakerV1) deliverEmissionReward(_ int, rlm realm, ctx *collectContext, reward Reward) (int64, int64) {
	communityPoolAddr := access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	internalReward := int64(0)
	internalRewardToUser := int64(0)
	internalRewardToFee := int64(0)
	internalRewardPenalty := int64(0)

	// Skip internal reward state update when user reward is zero (only penalty).
	// Do not update last collect time so the reward accrues until the next
	// collection where a non-zero amount can be delivered.
	skipInternalUpdate := reward.Internal == 0

	// internal reward to user
	if !skipInternalUpdate {
		toUser, feeAmount, err := s.handleStakingRewardFee(0, rlm, GNS_TOKEN_KEY, reward.Internal, true)
		if err != nil {
			panic(err.Error())
		}

		internalReward = reward.Internal
		internalRewardToUser = toUser
		internalRewardToFee = feeAmount
		internalRewardPenalty = reward.InternalPenalty

		chain.Emit(
			"ProtocolFeeInternalReward",
			"prevAddr", ctx.prevAddr,
			"prevRealm", ctx.prevRealm,
			"fromPositionId", utils.FormatUint(ctx.positionId),
			"fromPoolPath", ctx.deposit.TargetPoolPath(),
			"feeTokenPath", GNS_TOKEN_KEY,
			"feeAmount", utils.FormatInt(internalRewardToFee),
			"currentTime", utils.FormatInt(ctx.currentTime),
			"currentHeight", utils.FormatInt(ctx.blockHeight),
		)
	}

	totalEmissionSent := s.store.GetTotalEmissionSent()

	if internalRewardToUser > 0 {
		// internal reward to user
		totalEmissionSent = gnsmath.SafeAddInt64(totalEmissionSent, internalRewardToUser)
		ctx.depositResolver.addCollectedInternalReward(reward.Internal)
	}

	if internalRewardPenalty > 0 {
		// internal penalty to community pool
		totalEmissionSent = gnsmath.SafeAddInt64(totalEmissionSent, internalRewardPenalty)
		ctx.depositResolver.addCollectedInternalReward(internalRewardPenalty)
	}

	// Unclaimable must be processed after regular rewards so that accumulated
	// unclaimable amounts are reset in the same collect window.
	// Always at the current time, never at ctx.currentTime: this accumulator is pool-global, and
	// a checkpoint collect would rewind it to its exit timestamp, re-counting everything since as
	// unclaimable and paying it out of the shared reserve.
	unClaimableInternal := s.processUnClaimableReward(ctx.depositResolver.TargetPoolPath(), time.Now().Unix())
	if unClaimableInternal > 0 {
		totalEmissionSent = gnsmath.SafeAddInt64(totalEmissionSent, unClaimableInternal)
	}

	if err := s.store.SetTotalEmissionSent(0, rlm, totalEmissionSent); err != nil {
		panic(err)
	}

	if !skipInternalUpdate {
		// Update lastCollectTime for internal rewards (GNS emissions)
		if err := ctx.depositResolver.updateInternalRewardLastCollectTime(ctx.currentTime); err != nil {
			panic(err)
		}
	}

	ctx.persistDeposit(s)

	if internalRewardToUser > 0 {
		gns.Transfer(cross(rlm), ctx.deposit.Owner(), internalRewardToUser)
	}

	if internalRewardPenalty > 0 {
		gns.Transfer(cross(rlm), communityPoolAddr, internalRewardPenalty)
	}

	if unClaimableInternal > 0 {
		gns.Transfer(cross(rlm), communityPoolAddr, unClaimableInternal)
	}

	if !skipInternalUpdate {
		chain.Emit(
			"CollectReward",
			"prevAddr", ctx.prevAddr,
			"prevRealm", ctx.prevRealm,
			"positionId", utils.FormatUint(ctx.positionId),
			"poolPath", ctx.depositResolver.TargetPoolPath(),
			"recipient", ctx.depositResolver.Owner().String(),
			"rewardToken", GNS_TOKEN_KEY,
			"rewardAmount", utils.FormatInt(internalReward),
			"rewardToUser", utils.FormatInt(internalRewardToUser),
			"rewardToFee", utils.FormatInt(internalRewardToFee),
			"rewardPenalty", utils.FormatInt(internalRewardPenalty),
			"rewardUnClaimableAmount", utils.FormatInt(unClaimableInternal),
			"currentTime", utils.FormatInt(ctx.currentTime),
			"currentHeight", utils.FormatInt(ctx.blockHeight),
			"stakedLiquidity", ctx.stakedLiquidity.ToString(),
			"globalRewardRatioAccX128", ctx.globalAccX128.ToString(),
			"lowerTickOutsideAccX128", ctx.lowerOutsideAccX128.ToString(),
			"upperTickOutsideAccX128", ctx.upperOutsideAccX128.ToString(),
		)
	}

	return internalRewardToUser, internalRewardPenalty
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
func (s *stakerV1) UnStakeToken(_ int, rlm realm, positionId uint64) string { // poolPath
	access.AssertIsRlmCurrent(0, rlm)

	caller := rlm.Previous().Address()
	halt.AssertIsNotHaltedWithdraw()
	assertIsDepositor(s, caller, positionId)

	deposit := s.getDeposits().get(positionId)

	// unStaked status
	poolPath := deposit.TargetPoolPath()

	// record the exit checkpoint; collecting is left to the Collect* entry points
	s.recordUnstakedPosition(0, rlm, positionId, deposit, time.Now().Unix())

	if err := s.applyUnStake(positionId); err != nil {
		panic(err)
	}

	// transfer NFT ownership to origin owner
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	s.nftAccessor.TransferFrom(0, rlm, stakerAddr, deposit.Owner(), positionIdFrom(positionId))
	pn.SetPositionOperator(cross(rlm), positionId, ZERO_ADDRESS)

	// get position information for event
	liquidity := getLiquidity(positionId)
	tickLower, tickUpper := getTickOf(positionId)

	amount0, amount1 := s.calculateAmounts(poolPath, tickLower, tickUpper, liquidity)

	// Get pool and accumulator values for reward calculation tracking
	currentTime := time.Now().Unix()
	pool, _ := s.getPools().Get(poolPath)
	poolResolver := NewPoolResolver(pool)
	currentTick := s.poolAccessor.GetSlot0Tick(poolPath)

	globalAccX128, stakedLiquidity := poolResolver.globalRewardRatioAccumulationAt(currentTime)

	previousRealm := rlm.Previous()
	chain.Emit(
		"UnStakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", utils.FormatUint(positionId),
		"poolPath", poolPath,
		"owner", deposit.Owner().String(),
		"liquidity", liquidity.ToString(),
		"positionUpperTick", utils.FormatInt(tickUpper),
		"positionLowerTick", utils.FormatInt(tickLower),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"from", stakerAddr.String(),
		"to", deposit.Owner().String(),
		"currentTick", utils.FormatInt(currentTick),
		"stakedLiquidity", stakedLiquidity.ToString(),
		"globalRewardRatioAccX128", globalAccX128.ToString(),
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
	inRange, err := pn.IsInRange(positionId)
	if err != nil {
		return err
	}
	if inRange {
		poolResolver.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}

	upperTick := poolResolver.GetOrNewTick(depositResolver.TickUpper())
	NewTickResolver(upperTick).modifyDepositUpper(currentTime, signedLiquidity)
	pool.Ticks().SetTick(depositResolver.TickUpper(), upperTick)

	lowerTick := poolResolver.GetOrNewTick(depositResolver.TickLower())
	NewTickResolver(lowerTick).modifyDepositLower(currentTime, signedLiquidity)
	pool.Ticks().SetTick(depositResolver.TickLower(), lowerTick)

	s.getDeposits().remove(positionId)

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
	if getLiquidity(positionId).Lte(u256.Zero()) {
		return ufmt.Errorf(
			"%v: positionId(%d) has no liquidity",
			errZeroLiquidity, positionId,
		)
	}
	return nil
}

func getLiquidity(positionId uint64) *u256.Uint {
	liquidity, err := pn.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}

	return u256.MustFromDecimal(liquidity)
}

func getTickOf(positionId uint64) (int32, int32) {
	tickLower, err := pn.GetPositionTickLower(positionId)
	if err != nil {
		panic(err)
	}
	tickUpper, err := pn.GetPositionTickUpper(positionId)
	if err != nil {
		panic(err)
	}
	if tickUpper < tickLower {
		panic(ufmt.Sprintf("tickUpper(%d) is less than tickLower(%d)", tickUpper, tickLower))
	}
	return tickLower, tickUpper
}

// calculateAmounts calculates the amounts of token0 and token1 for a given liquidity and range.
func (s *stakerV1) calculateAmounts(poolPath string, tickLower, tickUpper int32, liquidity *u256.Uint) (*u256.Uint, *u256.Uint) {
	sqrtPriceX96 := u256.MustFromDecimal(s.poolAccessor.GetSlot0SqrtPriceX96(poolPath))
	sqrtPriceLowerX96 := gnsmath.TickMathGetSqrtRatioAtTick(tickLower)
	sqrtPriceUpperX96 := gnsmath.TickMathGetSqrtRatioAtTick(tickUpper)

	return gnsmath.GetAmountsForLiquidity(sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity)
}
