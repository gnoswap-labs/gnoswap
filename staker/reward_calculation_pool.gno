package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/avl"

	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
)

var q96 = u256.MustFromDecimal(consts.Q96)

type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func NewPools() *Pools {
	return &Pools{
		tree: avl.NewTree(),
	}
}

var pools = NewPools()

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
	stakedLiquidity *UintTree // blockNumber -> *u256.Uint

	// cache of the internal reward per liquidity for each pool in tier
	// value: (internal reward / total staked liquidity) * Q96
	rewardCache           *RewardCacheTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight *uint64

	incentives Incentives

	ticks *Ticks
}
		
func NewPool(poolPath string, currentHeight uint64) *Pool {
	return &Pool{
		poolPath: poolPath,
		stakedLiquidity: NewUintTree(),
		rewardCache: NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
		incentives: NewIncentives(currentHeight),
		ticks: NewTicks(),
	}
}

func (self *Pool) CurrentStakedLiquidity(currentHeight uint64) *u256.Uint {
	stakedLiquidityI, ok := self.stakedLiquidity.Get(currentHeight)
	if ok {
		return stakedLiquidityI.(*u256.Uint)
	}
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) CurrentReward(currentHeight uint64) uint64 {
	reward := self.rewardCache.CurrentReward(currentHeight)
	if reward == nil {
		return uint64(0)
	}
	return reward.(uint64)
} 

// cacheReward() MUST be called before this function
func (self *Pool) IsExternallyIncentivizedPool(currentHeight uint64) bool {
	return len(self.incentives.CurrentReward(currentHeight)) > 0
}
/*
func (self *Pool) StakedLiquidityUpdates(startHeight, endHeight uint64) ([]uint64, []*u256.Uint) {
	heights := make([]uint64, 0)
	updates := make([]*u256.Uint, 0)
	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		heights = append(heights, height)
		updates = append(updates, value.(*u256.Uint))
		return false
	})
	return heights, updates
}
*/

func (self *Pool) cacheRewardPerLiquidityUnit(poolTier *PoolTier, startHeight, endHeight uint64, currentTierReward uint64) {
	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		stakedLiquidity := value.(*u256.Uint)
		ratio := u256.NewUint(currentTierReward)
		ratio = ratio.Mul(ratio, q96)
		ratio = ratio.Div(ratio, stakedLiquidity)
		self.rewardCache.Set(height, ratio)
		return false
	})
}

func (self *Pool) cacheReward(poolTier *PoolTier, endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	currentTier := poolTier.CurrentTier(self.poolPath, startHeight)
	currentTierReward := uint64(0)
	poolTier.membershipOf(self.poolPath).Iterate(startHeight, endHeight, func(membershipUpdateHeight uint64, value interface{}) bool {
		if currentTier == 0 {
			// ignore reward updates
			startHeight = membershipUpdateHeight
			currentTier = value.(uint64)
			return false
		} 

		currentTierReward = poolTier.CurrentReward(currentTier, startHeight)

		poolTier.rewardCacheOf(currentTier).Iterate(startHeight, membershipUpdateHeight, func(rewardUpdateHeight uint64, value interface{}) bool {
			self.cacheRewardPerLiquidityUnit(poolTier, startHeight, rewardUpdateHeight, currentTierReward)
			currentTierReward = value.(uint64)
			startHeight = rewardUpdateHeight
			return false
		})
		currentTier = value.(uint64)
		if currentTier == 0 {
			self.rewardCache.Set(membershipUpdateHeight, uint64(0))
		} else {
			self.cacheRewardPerLiquidityUnit(poolTier, startHeight, membershipUpdateHeight, currentTierReward)
		}
		startHeight = membershipUpdateHeight
		return false
	})

	// take account of tier reward changes after the last tier membership change
	if currentTier == 0 {
		return
	}
	poolTier.rewardCacheOf(currentTier).Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.cacheRewardPerLiquidityUnit(poolTier, startHeight, height, currentTierReward)
		currentTierReward = value.(uint64)
		startHeight = height
		return false
	})
}

/*
func setInRange(currentlyInRange bool, targetInRange bool) bool {
	if currentlyInRange != targetInRange {
		return targetInRange
	}
	panic(addDetailToError(
		errInvalidTickCross,
		ufmt.Sprintf("staker.gno__tickCrossesToEligibleIntervals() || currentlyInRange(%t) is already equal with targetInRange(%t)", currentlyInRange, targetInRange),
	))
}
*/
/*
func (self *Pool) TickCrossesToInternalReward(
	tickUpperCrosses []int64,
	tickLowerCrosses []int64,
	currentlyInRange bool,
	startHeight,
	finalHeight uint64,
	f func(startHeight, endHeight uint64, stakedLiquidity *u256.Uint),
) {
	TickCrossesToInRanges(currentlyInRange, tickUpperCrosses, tickLowerCrosses, func(height int64, inRange bool) {
		if inRange {
			// enter range
			startHeight = uint64(height)
		} else {
			// exit range
			self.stakedLiquidityForInterval(self.CurrentStakedLiquidity(startHeight), startHeight, uint64(height), f)
		}
		currentlyInRange = inRange
	})

	if currentlyInRange {
		self.stakedLiquidityForInterval(self.CurrentStakedLiquidity(startHeight), startHeight, finalHeight, f)
	}
}
*/
type InternalRewardState struct {
	pool *Pool
	deposit *Deposit
	currentWarmup Warmup
	rewards []*u256.Uint
	penalties []*u256.Uint
}

func (self *Pool) InternalRewardOf(deposit *Deposit) *InternalRewardState {
	result := &InternalRewardState{
		pool: self,
		deposit: deposit,
		currentWarmup: deposit.warmups[0],
		rewards: make([]*u256.Uint, len(deposit.warmups)),
		penalties: make([]*u256.Uint, len(deposit.warmups)),
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
		positionLiquidity := self.deposit.liquidity.Clone()
		poolRewardRatio := poolRewardI.(*u256.Uint)
		positionReward := positionLiquidity.Mul(positionLiquidity, poolRewardRatio)
		positionReward = positionReward.Mul(positionReward, u256.NewUint(blockNumber))

		acc := self.rewards[self.currentWarmup.Index]
		acc.Add(acc, positionReward)
	})
}

func (self *InternalRewardState) ApplyWarmup() {
	for i, warmup := range self.deposit.warmups {
		if self.rewards[i].IsZero() {
			continue
		}
		reward := u256.Zero()
		reward = reward.Mul(self.rewards[i], u256.NewUint(warmup.WarmupRatio))
		reward = reward.Div(reward, u256.NewUint(100))
		reward = reward.Div(reward, q96)

		penalty := u256.Zero()
		penalty = penalty.Mul(self.rewards[i], u256.NewUint(100 - warmup.WarmupRatio))
		penalty = penalty.Div(penalty, u256.NewUint(100))
		penalty = penalty.Div(penalty, q96)

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
			tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
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
		tickUpperCrosses, tickLowerCrosses = ForEachEligibleInterval(
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

func (self *Pool) modifyDeposit(tokenId uint64, liquidity *i256.Int, currentHeight uint64) {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	self.stakedLiquidity.Set(currentHeight, liquidityMathAddDelta(lastStakedLiquidity, liquidity))
}


/*
func (self *Pool) stakedLiquidityForInterval(currentStakedLiquidity *u256.Uint, startHeight, endHeight uint64, f func(startHeight, endHeight uint64, stakedLiquidity *u256.Uint)) {
	if startHeight == endHeight {
		return
	}

	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		update := value.(*u256.Uint)

		f(startHeight, height, currentStakedLiquidity)

		startHeight = height
		currentStakedLiquidity = update

		return false
	})

	f(startHeight, endHeight, currentStakedLiquidity)
}
	*/