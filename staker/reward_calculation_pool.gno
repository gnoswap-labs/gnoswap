package staker

import (
	"std"

	"gno.land/p/demo/avl"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
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

func (self *Pools) GetOrCreate(poolPath string) *Pool {
	pool, ok := self.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, uint64(std.GetHeight()))
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
	stakedLiquidity       *UintTree // blockNumber -> *u256.Uint

	lastUnclaimableHeight *uint64
	unclaimableAcc *uint64

	tierRewardTotal *uint64 // current total internal reward per block, used for unclaimable reward calculation

	rewardCache           *RewardCacheTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight *uint64

	incentives Incentives

	ticks *Ticks
}

func NewPool(poolPath string, currentHeight uint64) *Pool {
	unclaimableAcc := uint64(0)
	tierRewardTotal := uint64(0)

	return &Pool{
		poolPath:              poolPath,
		stakedLiquidity:       NewUintTree(),
		lastUnclaimableHeight: &currentHeight,
		unclaimableAcc:        &unclaimableAcc,
		tierRewardTotal:       &tierRewardTotal,
		rewardCache:           NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
		incentives:            NewIncentives(currentHeight),
		ticks:                 NewTicks(),
	}
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

// cacheReward() MUST be called before this function
func (self *Pool) IsExternallyIncentivizedPool(currentHeight uint64) bool {
	return self.incentives.byTime.Size() != 0
}

func (self *Pool) updateRewardByLiquidityChange(currentTierReward uint64, currentHeight uint64, liquidity *u256.Uint) {
	ratio := u256.NewUint(currentTierReward)
	ratio = u256.Zero().Mul(ratio, q192)
	ratio = u256.Zero().Div(ratio, liquidity)
	self.rewardCache.Set(currentHeight, ratio)

	self.incentives.updateRewardByLiquidityChange(currentHeight, liquidity)
}

func (self *Pool) cacheRewardPerLiquidityUnit(startHeight, endHeight uint64, currentTierReward uint64) {
	// Unclaimable reward calculation uses tierRewardTotal, so we need to update it
	if *self.lastUnclaimableHeight != 0 {
		self.endInternalUnclaimablePeriod(startHeight)
		*self.tierRewardTotal = currentTierReward
		self.startInternalUnclaimablePeriod(endHeight)
	}

	if currentTierReward == 0 {
		self.rewardCache.Set(startHeight, u256.Zero())
		return
	}

	stakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.updateRewardByLiquidityChange(currentTierReward, startHeight, stakedLiquidity)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		stakedLiquidity := value.(*u256.Uint)
		self.updateRewardByLiquidityChange(currentTierReward, height, stakedLiquidity)

		return false
	})
}

func (self *Pool) cacheInternalReward(currentHeight uint64, emissionUpdate en.EmissionUpdate, rewardDenominator uint64) {
	currentEmission := emissionUpdate.LastEmissionUpdate

	startHeight := *self.lastRewardCacheHeight

	for i, height := range emissionUpdate.EmissionUpdateHeights {
		emission := emissionUpdate.EmissionUpdates[i]

		self.cacheRewardPerLiquidityUnit(startHeight, height, ApplyDenominator(currentEmission, rewardDenominator))
		startHeight = height

		currentEmission = emission
	}

	self.cacheRewardPerLiquidityUnit(startHeight, currentHeight, ApplyDenominator(currentEmission, rewardDenominator))
	*self.lastRewardCacheHeight = currentHeight
}

func (self *Pool) cacheExternalReward(endHeight uint64) {
	self.stakedLiquidity.Iterate(0, 9999999, func(key uint64, value interface{}) bool {
		return false
	})

	startHeight := *self.incentives.lastRewardCacheHeight
	currentStakedLiquidity := self.CurrentStakedLiquidity(startHeight)

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.incentives.cacheRewardPerLiquidityUnit(startHeight, height, currentStakedLiquidity)
		currentStakedLiquidity = value.(*u256.Uint)
		startHeight = height
		return false
	})

	self.incentives.cacheRewardPerLiquidityUnit(startHeight, endHeight, currentStakedLiquidity)

	self.incentives.rewardCache.Iterate(0, 9999999, func(key uint64, value interface{}) bool {
		return false
	})
}

type ExternalRewardState struct {
	pool          *Pool
	deposit       *Deposit
	currentWarmup Warmup
	rewards       []map[string]*u256.Uint
	penalties     []map[string]*u256.Uint
}

func (self *Pool) ExternalRewardOf(deposit *Deposit) *ExternalRewardState {
	result := &ExternalRewardState{
		pool:          self,
		deposit:       deposit,
		currentWarmup: deposit.warmups[0],
		rewards:       make([]map[string]*u256.Uint, len(deposit.warmups)),
		penalties:     make([]map[string]*u256.Uint, len(deposit.warmups)),
	}

	for i := range result.rewards {
		result.rewards[i] = make(map[string]*u256.Uint)
		result.penalties[i] = make(map[string]*u256.Uint)
	}

	return result
}

func (self *ExternalRewardState) Calculate(startHeight, endHeight int64, currentlyInRange bool, tickUpperCrosses []int64, tickLowerCrosses []int64) ([]map[string]uint64, []map[string]uint64) {
	if !self.pool.IsExternallyIncentivizedPool(uint64(startHeight)) {
		return nil, nil
	}

	self.TickCrossesToExternalReward(startHeight, endHeight, currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	rewards := make([]map[string]uint64, len(self.deposit.warmups))
	penalties := make([]map[string]uint64, len(self.deposit.warmups))


	for i := range self.rewards {
		rewards[i] = make(map[string]uint64)
		penalties[i] = make(map[string]uint64)
		for incentiveId, reward := range self.rewards[i] {
			rewards[i][incentiveId] = reward.Uint64()
		}
		for incentiveId, penalty := range self.penalties[i] {
			penalties[i][incentiveId] = penalty.Uint64()
		}
	}

	return rewards, penalties
}

func (self *ExternalRewardState) AccumulateReward(startHeight, endHeight uint64) {
	self.pool.incentives.rewardCache.RewardPerInterval(startHeight, endHeight, func(blockNumber uint64, poolRewardI interface{}) {
		incentiveRewardEntry := poolRewardI.(IncentiveRewardEntry)
		for _, incentiveId := range incentiveRewardEntry.ActiveIncentives {
			incentive, ok := self.pool.incentives.GetByIncentiveId(incentiveId)
			if !ok {
				panic("incentive not found")
			}
			rewardRatio := u256.NewUint(incentive.rewardPerBlock)
			rewardRatio.Mul(rewardRatio, q192)
			rewardRatio.Div(rewardRatio, incentiveRewardEntry.TotalStakedLiquidity)
			positionReward := u256.Zero().Mul(self.deposit.liquidity, rewardRatio)
			positionReward = u256.Zero().Mul(positionReward, u256.NewUint(blockNumber))
			acc, ok := self.rewards[self.currentWarmup.Index][incentiveId]
			if !ok {
				acc = u256.Zero()
			}
			acc.Add(acc, positionReward)
			self.rewards[self.currentWarmup.Index][incentiveId] = acc
		}
	})

}

func (self *ExternalRewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		for incentiveId, reward := range self.rewards[i] {
			if reward.IsZero() {
				continue
			}
			warmupReward := u256.Zero()
			warmupReward = warmupReward.Mul(reward, u256.NewUint(warmup.WarmupRatio))
			warmupReward = warmupReward.Div(warmupReward, u256.NewUint(100))

			warmupPenalty := u256.Zero().Sub(reward, warmupReward)

			warmupReward = warmupReward.Div(warmupReward, q192)
			warmupPenalty = warmupPenalty.Div(warmupPenalty, q192)

			self.rewards[i][incentiveId] = warmupReward
			self.penalties[i][incentiveId] = warmupPenalty
		}
	}
}

func (self *ExternalRewardState) TickCrossesToExternalReward(startHeight, endHeight int64, currentlyInRange bool, tickUpperCrosses []int64, tickLowerCrosses []int64) {
	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			// fully submerged in the current warmup
			currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
				startHeight,
				endHeight,
				currentlyInRange,
				tickUpperCrosses,
				tickLowerCrosses,
				self.AccumulateReward,
			)

			// done
			break
		}

		// partially included in the current warmup
		currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
			startHeight,
			warmup.NextWarmupHeight,
			currentlyInRange,
			tickUpperCrosses,
			tickLowerCrosses,
			self.AccumulateReward,
		)
		startHeight = warmup.NextWarmupHeight
	}

	self.ApplyWarmup()
}

type InternalRewardState struct {
	pool          *Pool
	deposit       *Deposit
	currentWarmup Warmup
	rewards       []*u256.Uint
	penalties     []*u256.Uint
}

func (self *Pool) InternalRewardOf(deposit *Deposit) *InternalRewardState {
	result := &InternalRewardState{
		pool:          self,
		deposit:       deposit,
		currentWarmup: deposit.warmups[0],
		rewards:       make([]*u256.Uint, len(deposit.warmups)),
		penalties:     make([]*u256.Uint, len(deposit.warmups)),
	}

	for i := range result.rewards {
		result.rewards[i] = u256.Zero()
		result.penalties[i] = u256.Zero()
	}

	return result
}

func (self *InternalRewardState) Calculate(startHeight, endHeight int64, currentlyInRange bool, tickUpperCrosses []int64, tickLowerCrosses []int64) ([]uint64, []uint64) {
	self.TickCrossesToInternalReward(startHeight, endHeight, currentlyInRange, tickUpperCrosses, tickLowerCrosses)

	rewards := make([]uint64, len(self.deposit.warmups))
	penalties := make([]uint64, len(self.deposit.warmups))

	for i, reward := range self.rewards {
		rewards[i] = reward.Uint64()
		penalties[i] = self.penalties[i].Uint64()
	}

	return rewards, penalties
}

func (self *InternalRewardState) AccumulateReward(startHeight, endHeight uint64) {
	self.pool.rewardCache.RewardPerInterval(startHeight, endHeight, func(blockNumber uint64, poolRewardI interface{}) {
		poolRewardRatio := poolRewardI.(*u256.Uint)
		positionReward := u256.Zero().Mul(self.deposit.liquidity, poolRewardRatio)
		positionReward = u256.Zero().Mul(positionReward, u256.NewUint(blockNumber))

		acc := self.rewards[self.currentWarmup.Index]
		acc.Add(acc, positionReward)
		self.rewards[self.currentWarmup.Index] = acc
	})
}

func (self *InternalRewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		if self.rewards[i].IsZero() {
			continue
		}
		reward := u256.Zero()
		totalReward := u256.Zero().Div(self.rewards[i], q192)

		reward = reward.Mul(self.rewards[i], u256.NewUint(warmup.WarmupRatio))
		reward = reward.Div(reward, u256.NewUint(100))
		reward = reward.Div(reward, q192)

		penalty := u256.Zero().Sub(totalReward, reward)

		self.rewards[i] = reward
		self.penalties[i] = penalty
	}
}

func (self *InternalRewardState) TickCrossesToInternalReward(startHeight, endHeight int64, currentlyInRange bool, tickUpperCrosses []int64, tickLowerCrosses []int64) {

	for _, warmup := range self.deposit.warmups {
		self.currentWarmup = warmup

		if startHeight >= warmup.NextWarmupHeight {
			// passed the warmup
			continue
		}

		if endHeight < warmup.NextWarmupHeight {
			// fully submerged in the current warmup
			currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
				startHeight,
				endHeight,
				currentlyInRange,
				tickUpperCrosses,
				tickLowerCrosses,
				self.AccumulateReward,
			)

			// done
			break
		}

		// partially included in the current warmup
		currentlyInRange, tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
			startHeight,
			warmup.NextWarmupHeight,
			currentlyInRange,
			tickUpperCrosses,
			tickLowerCrosses,
			self.AccumulateReward,
		)
		startHeight = warmup.NextWarmupHeight
	}

	self.ApplyWarmup()
}

func (self *Pool) modifyDeposit(tokenId uint64, delta *i256.Int, currentHeight uint64) {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	deltaApplied := liquidityMathAddDelta(lastStakedLiquidity, delta)
	self.stakedLiquidity.Set(currentHeight, deltaApplied)
	self.updateRewardByLiquidityChange(*self.tierRewardTotal, currentHeight, deltaApplied)
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
	startHeight := *self.lastUnclaimableHeight
	internalUnClaimable := *self.unclaimableAcc
	*self.unclaimableAcc = 0
	externalUnClaimable := make(map[string]uint64)
	for _, incentiveId := range self.incentives.CurrentReward(startHeight).ActiveIncentives {
		externalUnClaimable[incentiveId] = self.UnclaimableExternalReward(incentiveId, startHeight, endHeight)
	}
	self.lastUnclaimableHeight = &endHeight
	return internalUnClaimable, externalUnClaimable
}