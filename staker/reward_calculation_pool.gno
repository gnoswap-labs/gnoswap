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
		pool = NewPool(poolPath, std.GetHeight(), currentTick)
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

	lastUnclaimableHeight int64
	unclaimableAcc        uint64

	tierRewardTotal uint64 // current total internal reward per block, used for unclaimable reward calculation

	// stores per-block reward for this pool at a given height
	rewardCache           *RewardCacheTree // blockNumber -> uint64
	lastRewardCacheHeight int64

	incentives Incentives

	ticks *Ticks

	// BlockNumber / TotalStake accumulation, Q128.
	globalRewardRatioAccumulation *UintTree // blockNumber -> *u256.Uint
	// lastGlobalRewardRatioAccumulationHeight *uint64

	historicalTick *UintTree // blockNumber -> int32
}

func NewPool(poolPath string, currentHeight int64, currentTick int32) *Pool {
	pool := &Pool{
		poolPath:              poolPath,
		stakedLiquidity:       NewUintTree(),
		lastUnclaimableHeight: currentHeight,
		unclaimableAcc:        0,
		tierRewardTotal:       0,
		rewardCache:           NewRewardCacheTree(),
		lastRewardCacheHeight: currentHeight,
		incentives:            NewIncentives(),
		ticks:                 NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		historicalTick: NewUintTree(),
	}

	pool.globalRewardRatioAccumulation.Set(currentHeight, u256.Zero())
	pool.historicalTick.Set(currentHeight, int32(currentTick))

	return pool
}

// Returns the latest staked liquidity at the height equal or before the current height
func (self *Pool) CurrentStakedLiquidity(currentHeight int64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight, func(key int64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) CurrentReward(currentHeight int64) *u256.Uint {
	reward := self.rewardCache.CurrentReward(currentHeight)
	if reward == nil {
		return u256.Zero()
	}
	return reward.(*u256.Uint)
}

func (self *Pool) CurrentGlobalRewardRatioAccumulation(currentHeight int64) (int64, *u256.Uint) {
	var height int64
	var acc *u256.Uint
	self.globalRewardRatioAccumulation.ReverseIterate(0, currentHeight, func(key int64, value interface{}) bool {
		height = key
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		panic("should not happen, globalRewardRatioAccumulation must be set when pool is created")
	}
	return height, acc
}

func (self *Pool) CurrentTick(currentHeight int64) int32 {
	var tick int32
	self.historicalTick.ReverseIterate(0, currentHeight, func(key int64, value interface{}) bool {
		tick = value.(int32)
		return true
	})
	return tick
}

func (self *Pool) IsExternallyIncentivizedPool(currentHeight int64) bool {
	return self.incentives.byTime.Size() != 0
}

func (self *Pool) cacheReward(startHeight, endHeight int64, currentTierReward uint64) {
	// Unclaimable reward calculation uses tierRewardTotal, so we need to update it
	if self.lastUnclaimableHeight != 0 {
		self.endUnclaimablePeriod(startHeight, false)
		self.tierRewardTotal = currentTierReward
		self.startUnclaimablePeriod(startHeight, false)
	}

	oldTierReward := self.rewardCache.CurrentReward(startHeight)
	if oldTierReward != currentTierReward {
		self.rewardCache.Set(startHeight, currentTierReward)
	}
}

func (self *Pool) cacheInternalReward(currentHeight int64, currentEmission uint64) {
	startHeight := self.lastRewardCacheHeight

	self.cacheReward(startHeight, currentHeight, currentEmission)

	if self.lastUnclaimableHeight != 0 && self.CurrentStakedLiquidity(currentHeight).IsZero() {
		self.endUnclaimablePeriod(currentHeight, false)
		self.startUnclaimablePeriod(currentHeight, false)
	}

	self.lastRewardCacheHeight = currentHeight

	self.updateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
}

func (self *Pool) calculateGlobalRewardRatioAccumulation(currentHeight int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
	oldAccHeight, oldAcc := self.CurrentGlobalRewardRatioAccumulation(currentHeight)
	blockDiff := currentHeight - oldAccHeight
	if blockDiff == 0 {
		return oldAcc.Clone()
	}

	acc := u256.NewUint(uint64(blockDiff))
	acc = acc.Mul(acc, q128)
	acc = acc.Div(acc, currentStakedLiquidity)

	return u256.Zero().Add(oldAcc, acc)
}

// returns the old global reward ratio accumulation
func (self *Pool) updateGlobalRewardRatioAccumulation(currentHeight int64, currentStakedLiquidity *u256.Uint) *u256.Uint {
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
	currentReward := rewardCache.CurrentReward(startHeight).(uint64)
	rewardCache.Iterate(startHeight, endHeight, func(key int64, value interface{}) bool {
		// we calculate per-position reward
		self.RewardPerWarmup(startHeight, int64(key), currentReward)
		currentReward = value.(uint64)
		startHeight = int64(key)
		self.currentWarmup = self.deposit.warmups[0]
		return false
	})

	if startHeight < endHeight {
		self.RewardPerWarmup(startHeight, endHeight, currentReward)
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
		return nil, nil // Not started yet
	}

	if startHeight < incentive.startHeight {
		startHeight = incentive.startHeight
	}

	if endHeight > incentive.endHeight {
		endHeight = incentive.endHeight
	}

	if startHeight > incentive.endHeight {
		return nil, nil // Already ended
	}

	rewardPerBlock := incentive.rewardPerBlock

	self.RewardPerWarmup(startHeight, endHeight, rewardPerBlock)

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

func (self *RewardState) RewardPerWarmup(startHeight, endHeight int64, rewardPerBlock uint64) {
	println("[[[RewardPerWarmup]]] startHeight : ", startHeight, ", endHeight : ", endHeight, ", rewardPerBlock : ", rewardPerBlock)
	
	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			rewardAcc := self.pool.CalculateRewardForPosition(startHeight, self.pool.CurrentTick(startHeight), endHeight, self.pool.CurrentTick(endHeight), self.deposit)

			rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
			rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(rewardPerBlock))
			rewardAcc = rewardAcc.Div(rewardAcc, q128)

			self.rewards[self.currentWarmup.Index] += rewardAcc.Uint64()

			// done
			break
		}

		rewardAcc := self.pool.CalculateRewardForPosition(startHeight, self.pool.CurrentTick(startHeight), warmup.NextWarmupHeight, self.pool.CurrentTick(warmup.NextWarmupHeight), self.deposit)

		rewardAcc = rewardAcc.Mul(rewardAcc, self.deposit.liquidity)
		rewardAcc = rewardAcc.Mul(rewardAcc, u256.NewUint(rewardPerBlock))
		rewardAcc = rewardAcc.Div(rewardAcc, q128)

		self.rewards[self.currentWarmup.Index] += rewardAcc.Uint64()

		startHeight = warmup.NextWarmupHeight
	}

	self.deposit.claimHeight = endHeight
}

func (self *Pool) modifyDeposit(delta *i256.Int, currentHeight int64, nextTick int32) *u256.Uint {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	result := self.updateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))

	// historical tick does NOT actually reflect the tick at the blockNumber, but it provides correct ordering for the staked positions.
	// (because TickCrossHook is called only for the staked-initialized ticks)
	// you should not use the historical tick for equality, only for comparison.
	self.historicalTick.Set(currentHeight, nextTick)

	switch deltaApplied.Sign() {
	case -1:
		panic("stakedLiquidity is less than 0")
	case 0:
		if lastStakedLiquidity.Sign() == 1 {
			// StakedLiquidity moved from positive to zero, start unclaimable period
			self.startUnclaimablePeriod(currentHeight, true)
		}
	case 1:
		if lastStakedLiquidity.Sign() == 0 {
			// StakedLiquidity moved from zero to positive, end unclaimable period
			self.endUnclaimablePeriod(currentHeight, true)
		}
	}

	self.stakedLiquidity.Set(currentHeight, deltaApplied)

	return result
}

func (self *Pool) startUnclaimablePeriod(currentHeight int64, external bool) {
	if self.lastUnclaimableHeight == 0 {
		// We set only if it's the first time entering(0 indicates not set yet)
		// PoolTier can set lastUnclaimable other than tickCrossHook when
		// cacheInternalReward() updates currentTierReward
		self.lastUnclaimableHeight = currentHeight

		if external {
			self.incentives.startUnclaimablePeriod(currentHeight)
		}
	}
}

func (self *Pool) endUnclaimablePeriod(currentHeight int64, external bool) {
	if self.lastUnclaimableHeight == 0 {
		// This should not happen, but guarding just in case
		return
	}
	if external {
		self.incentives.endUnclaimablePeriod(currentHeight)
	}
	unclaimableHeights := currentHeight - self.lastUnclaimableHeight
	self.lastUnclaimableHeight = 0
	self.unclaimableAcc += uint64(unclaimableHeights) * self.tierRewardTotal

}

func (self *Pool) processUnclaimableReward(poolTier *PoolTier, endHeight int64) uint64 {
	internalUnClaimable := self.unclaimableAcc
	self.unclaimableAcc = 0
	self.lastUnclaimableHeight = endHeight
	return internalUnClaimable
}

// Calculates reward for a position, *without* considering debt or warmup
func (self *Pool) CalculateRawRewardForPosition(currentHeight int64, currentTick int32, deposit *Deposit) *u256.Uint {
	var rewardAcc *u256.Uint

	globalAcc := self.calculateGlobalRewardRatioAccumulation(currentHeight, self.CurrentStakedLiquidity(currentHeight))
	println("	globalAcc : ", globalAcc.Uint64())
	lowerAcc := self.ticks.Get(deposit.tickLower).CurrentOutsideAccumulation(currentHeight)
	println("	lowerAcc : ", lowerAcc.Uint64())
	upperAcc := self.ticks.Get(deposit.tickUpper).CurrentOutsideAccumulation(currentHeight)
	println("	upperAcc : ", upperAcc.Uint64())
	println("	currentTick : ", currentTick)
	println("	deposit.tickLower : ", deposit.tickLower)
	println("	deposit.tickUpper : ", deposit.tickUpper)

	if currentTick < deposit.tickLower {
		println("	currentTick < deposit.tickLower")
		rewardAcc = u256.Zero().Sub(lowerAcc, upperAcc)
	} else if currentTick >= deposit.tickUpper {
		println("	currentTick >= deposit.tickUpper")
		rewardAcc = u256.Zero().Sub(upperAcc, lowerAcc)
	} else {
		println("	currentTick >= deposit.tickLower && currentTick < deposit.tickUpper")
		rewardAcc = u256.Zero().Sub(globalAcc, lowerAcc)
		rewardAcc = rewardAcc.Sub(rewardAcc, upperAcc)
	}

	return rewardAcc
}

// Applying debt and claiming
func (self *Pool) CalculateRewardForPosition(startHeight int64, startTick int32, endHeight int64, endTick int32, deposit *Deposit) *u256.Uint {
	rewardAcc := self.CalculateRawRewardForPosition(endHeight, endTick, deposit)
	println("	rewardAcc : ", rewardAcc.Uint64())

	debtAcc := self.CalculateRawRewardForPosition(startHeight, startTick, deposit)
	println("	debtAcc : ", debtAcc.Uint64())

	rewardAcc = rewardAcc.Sub(rewardAcc, debtAcc)

	return rewardAcc
}
