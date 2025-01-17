package staker

import (
	"std"

	"gno.land/p/demo/avl"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"

	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	// Q128 is 2^128
	q128 = u256.MustFromDecimal(consts.Q128)
	// Q192 is 2^192
	q192 = u256.MustFromDecimal("6277101735386680763835789423207666416102355444464034512895")

	// pools is the global pool storage
	pools *Pools
)

func init() {
	pools = NewPools()
}

type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func NewPools() *Pools {
	return &Pools{
		tree: avl.NewTree(),
	}
}

func (self *Pools) Get(poolPath string) (*Pool, bool) {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		return nil, false
	}
	return v.(*Pool), true
}

func (self *Pools) GetOrCreate(poolPath string, currentTick int32) *Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, uint64(std.GetHeight()), currentTick)
		self.Set(poolPath, pool)
	}
	return pool
}

func (self *Pools) Set(poolPath string, pool *Pool) {
	self.tree.Set(poolPath, pool)
}

func (self *Pools) Has(poolPath string) bool {
	return self.tree.Has(poolPath)
}

type Pool struct {
	poolPath string

	// conceptually equal with Pool.liquidity but only for the staked positions
	// updated each time when the pool crosses a staked tick
	stakedLiquidity *UintTree // blockNumber -> *u256.Uint

	lastUnclaimableHeight *uint64
	unclaimableAcc        *uint64

	tierRewardTotal *uint64 // current total internal reward per block, used for unclaimable reward calculation

	// stores per-block reward for this pool at a given height
	rewardCache           *RewardCacheTree // blockNumber -> uint64
	lastRewardCacheHeight *uint64

	incentives Incentives

	ticks *Ticks

	// BlockNumber / TotalStake accumulation, Q128.
	globalRewardRatioAccumulation *UintTree // blockNumber -> *u256.Uint
	// lastGlobalRewardRatioAccumulationHeight *uint64

	historicalTick *UintTree // blockNumber -> int32
}

func NewPool(poolPath string, currentHeight uint64, currentTick int32) *Pool {
	unclaimableAcc := uint64(0)
	tierRewardTotal := uint64(0)
	// For some reason we cannot use &currentHeight directly
	// currentHeightVar := currentHeight

	pool := &Pool{
		poolPath:              poolPath,
		stakedLiquidity:       NewUintTree(),
		lastUnclaimableHeight: &currentHeight,
		unclaimableAcc:        &unclaimableAcc,
		tierRewardTotal:       &tierRewardTotal,
		rewardCache:           NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
		incentives:            NewIncentives(currentHeight),
		ticks:                 NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		// lastGlobalRewardRatioAccumulationHeight: &currentHeightVar,
		historicalTick: NewUintTree(),
	}

	pool.globalRewardRatioAccumulation.Set(currentHeight, u256.Zero())
	pool.historicalTick.Set(currentHeight, int32(currentTick))

	return pool
}

// Returns the latest staked liquidity at the height equal or before the current height
func (self *Pool) CurrentStakedLiquidity(currentHeight uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) CurrentReward(currentHeight uint64) *u256.Uint {
	reward := self.rewardCache.CurrentReward(currentHeight)
	if reward == nil {
		return u256.Zero()
	}
	return reward.(*u256.Uint)
}

func (self *Pool) CurrentGlobalRewardRatioAccumulation(currentHeight uint64) (uint64, *u256.Uint) {
	var height uint64
	var acc *u256.Uint
	self.globalRewardRatioAccumulation.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		height = key
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardRatioAccumulation must be set when pool is created")
	}
	return height, acc
}

func (self *Pool) CurrentTick(currentHeight uint64) int32 {
	var tick int32
	self.historicalTick.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		tick = value.(int32)
		return true
	})
	return tick
}

// cacheReward() MUST be called before this function
func (self *Pool) IsExternallyIncentivizedPool(currentHeight uint64) bool {
	return self.incentives.byTime.Size() != 0
}

func (self *Pool) cacheReward(startHeight, endHeight uint64, currentTierReward uint64) {
	println("\t\t\t->cacheRewardPerLiquidityUnit Start : [", startHeight, "], [", endHeight, "], (", currentTierReward, "), lastUnclaimableHeight ", *self.lastUnclaimableHeight, ", currentTierReward : ", currentTierReward)
	// Unclaimable reward calculation uses tierRewardTotal, so we need to update it
	if *self.lastUnclaimableHeight != 0 {
		self.endInternalUnclaimablePeriod(startHeight)
		*self.tierRewardTotal = currentTierReward
		println("		->tierRewardTotal : ", *self.tierRewardTotal)
		self.startInternalUnclaimablePeriod(startHeight)
	}

	oldTierReward := self.rewardCache.CurrentReward(startHeight)
	if oldTierReward != currentTierReward {
		self.rewardCache.Set(startHeight, currentTierReward)
	}
}

func (self *Pool) cacheInternalReward(currentHeight, currentEmission uint64) {
	startHeight := *self.lastRewardCacheHeight

	self.cacheReward(startHeight, currentHeight, currentEmission)

	if *self.lastUnclaimableHeight != 0 && self.CurrentStakedLiquidity(currentHeight).IsZero() {
		self.endInternalUnclaimablePeriod(currentHeight)
		self.startInternalUnclaimablePeriod(currentHeight)
	}

	*self.lastRewardCacheHeight = currentHeight
	println("\t\tlastRewardCacheHeight : ", *self.lastRewardCacheHeight)

	self.updateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
}

func (self *Pool) calculateGlobalRewardRatioAccumulation(currentHeight uint64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccHeight, oldAcc := self.CurrentGlobalRewardRatioAccumulation(currentHeight)
	blockDiff := currentHeight - oldAccHeight
	if blockDiff == 0 {
		return oldAcc.Clone()
	}

	acc := u256.NewUint(blockDiff)
	acc = acc.Mul(acc, q128)
	acc = acc.Div(acc, currentStakedLiquidity)

	return u256.Zero().Add(oldAcc, acc)
}

// returns the old global reward ratio accumulation
func (self *Pool) updateGlobalRewardRatioAccumulation(currentHeight uint64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	newAcc := self.calculateGlobalRewardRatioAccumulation(currentHeight, currentStakedLiquidity)

	self.globalRewardRatioAccumulation.Set(currentHeight, newAcc)
	return newAcc
}

type RewardState struct {
	pool *Pool
	deposit       *Deposit
	currentWarmup Warmup

	rewards []uint64
	penalties []uint64
}

func (self *Pool) RewardStateOf(deposit *Deposit) *RewardState {
	result := &RewardState{
		pool: self,
		deposit:       deposit,
		currentWarmup: deposit.warmups[0],
		rewards:       make([]uint64, len(deposit.warmups)),
		penalties:     make([]uint64, len(deposit.warmups)),
	}

	for i := range result.rewards {
		result.rewards[i] = 0
		result.penalties[i] = 0
	}

	return result
}

func (self *RewardState) CalculateInternalReward(startHeight, endHeight int64, rewardCache *RewardCacheTree) ([]uint64, []uint64) {
	currentReward := rewardCache.CurrentReward(uint64(startHeight)).(uint64)
	rewardCache.Iterate(uint64(startHeight), uint64(endHeight), func(key uint64, value interface{}) bool {
		// we calculate per-position reward
		self.TickCrossesToReward(startHeight, int64(key), currentReward)
		currentReward = value.(uint64)
		startHeight = int64(key)
		self.currentWarmup = self.deposit.warmups[0]
		return false
	})

	if startHeight < endHeight {
		self.TickCrossesToReward(startHeight, endHeight, currentReward)
	}

	self.ApplyWarmup()

	return self.rewards, self.penalties
}

func (self *RewardState) CalculateExternalReward(startHeight, endHeight int64, incentive *ExternalIncentive) ([]uint64, []uint64) {
	if startHeight < int64(self.deposit.lastCollectHeight) {
		// This must not happen, but adding some guards just in case.
		startHeight = int64(self.deposit.lastCollectHeight)
	}

	if endHeight < incentive.startHeight {
		println("[[[CalculateExternalReward NOT STARTED]]]", startHeight, incentive.startHeight)
		return nil, nil // Not started yet
	}

	if startHeight < incentive.startHeight {
		startHeight = incentive.startHeight
	}

	if endHeight > incentive.endHeight {
		endHeight = incentive.endHeight
	}

	if startHeight > incentive.endHeight {
		println("[[[CalculateExternalReward ALREADY ENDED]]]")
		return nil, nil // Already ended
	}

	rewardPerBlock := incentive.rewardPerBlock

	self.TickCrossesToReward(startHeight, endHeight, rewardPerBlock)

	self.ApplyWarmup()

	return self.rewards, self.penalties
}

func (self *RewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		refactorReward := self.rewards[i]
		self.rewards[i] = refactorReward * warmup.WarmupRatio / 100
		self.penalties[i] = refactorReward - self.rewards[i]
	}
}

func abs(x int64) uint64 {
	if x < 0 {
		return uint64(-x)
	}
	return uint64(x)
}

func (self *RewardState) TickCrossesToReward(startHeight, endHeight int64, rewardPerBlock uint64) {
	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(endHeight), self.pool.CurrentTick(uint64(endHeight)), self.deposit)

			rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
			rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(rewardPerBlock))
			rewardAcc = rewardAcc.Div(rewardAcc, q128)

			self.rewards[self.currentWarmup.Index] += rewardAcc.Uint64()

			// done
			break
		}

		rewardAcc := self.pool.CalculateRewardForPosition(uint64(startHeight), self.pool.CurrentTick(uint64(startHeight)), uint64(warmup.NextWarmupHeight), self.pool.CurrentTick(uint64(warmup.NextWarmupHeight)), self.deposit)

		rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
		rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(rewardPerBlock))
		rewardAcc = rewardAcc.Div(rewardAcc, q128)

		self.rewards[self.currentWarmup.Index] += rewardAcc.Uint64()

		startHeight = warmup.NextWarmupHeight
	}

	self.deposit.claimHeight = uint64(endHeight)
}

func (self *Pool) modifyDeposit(tokenId uint64, delta *i256.Int, currentHeight uint64) {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	self.stakedLiquidity.Set(currentHeight, deltaApplied)
	self.updateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
}

func (self *Pool) startInternalUnclaimablePeriod(currentHeight uint64) {
	if *self.lastUnclaimableHeight == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		// PoolTier can set lastUnclaimable other than tickCrossHook when
		// cacheInternalReward() updates currentTierReward
		*self.lastUnclaimableHeight = currentHeight
	}
}

func (self *Pool) endInternalUnclaimablePeriod(currentHeight uint64) {
	if *self.lastUnclaimableHeight == 0 {
		// This should not happen, but guarding just in case
		return
	}
	unclaimableHeights := currentHeight - *self.lastUnclaimableHeight
	*self.lastUnclaimableHeight = 0
	*self.unclaimableAcc += unclaimableHeights * *self.tierRewardTotal
}

func (self *Pool) UnclaimableExternalReward(incentiveId string, startHeight, endHeight uint64) uint64 {
	incentive, ok := self.incentives.GetByIncentiveId(incentiveId)
	if !ok {
		return 0
	}

	if startHeight > uint64(incentive.endHeight) || endHeight < uint64(incentive.startHeight) {
		return 0
	}

	if startHeight < uint64(incentive.startHeight) {
		startHeight = uint64(incentive.startHeight)
	}

	if endHeight > uint64(incentive.endHeight) {
		endHeight = uint64(incentive.endHeight)
	}

	rewardPerBlock := incentive.rewardPerBlock

	unclaimable := uint64(0)

	currentStakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		if currentStakedLiquidity.IsZero() {
			unclaimable += rewardPerBlock * (height - startHeight)
		}
		startHeight = height
		currentStakedLiquidity = value.(*u256.Uint)
		return false
	})

	if currentStakedLiquidity.IsZero() {
		unclaimable += rewardPerBlock * (endHeight - startHeight)
	}

	return unclaimable
}

func (self *Pool) processUnclaimableReward(poolTier *PoolTier, endHeight uint64) (uint64, map[string]uint64) {
	//startHeight := *self.lastUnclaimableHeight
	internalUnClaimable := *self.unclaimableAcc
	*self.unclaimableAcc = 0
	self.lastUnclaimableHeight = &endHeight
	return internalUnClaimable, make(map[string]uint64)
}

// Calculates reward for a position, *without* considering debt or warmup
func (self *Pool) CalculateRawRewardForPosition(currentHeight uint64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentHeight)
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentHeight)

	println("currentTick : ", currentTick)
	println("deposit.tickLower : ", deposit.tickLower)
	println("deposit.tickUpper : ", deposit.tickUpper)

	if currentTick < deposit.tickLower {
		println("currentTick < lowerTick")
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(lowerAcc, upperAcc)
	} else if currentTick >= deposit.tickUpper {
		println("currentTick >= upperTick")
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(upperAcc, lowerAcc)
	} else {
		println("currentTick >= lowerTick && currentTick < upperTick")
		println("globalAcc : ", globalAcc.ToString())
		println("lowerAcc : ", lowerAcc.ToString())
		println("upperAcc : ", upperAcc.ToString())
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}

// Applying debt and claiming
func (self *Pool) CalculateRewardForPosition(startHeight uint64, startTick int32, endHeight uint64, endTick int32, deposit *Deposit) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(endHeight, endTick, deposit)
	println("rewardAcc 1 : ", rewardAcc.ToString())

	debtAcc := self.CalculateRawRewardForPosition(startHeight, startTick, deposit)
	println("debtAcc : ", debtAcc.ToString())
	rewardAcc = rewardAcc.Sub(rewardAcc, debtAcc)
	println("rewardAcc 2 : ", rewardAcc.ToString())

	return rewardAcc
}
