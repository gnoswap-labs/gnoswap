package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
)

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

	// cache of the internal reward for each pool in tier
	rewardCache           *RewardCacheTree // blockNumber -> uint64 
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

func (self *Pool) cacheReward(poolTier *PoolTier, endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	currentTier := poolTier.CurrentTier(self.poolPath, startHeight)
	poolTier.membershipOf(self.poolPath).Iterate(startHeight, endHeight, func(membershipUpdateHeight uint64, value interface{}) bool {
		if currentTier == 0 {
			// ignore reward updates
			startHeight = membershipUpdateHeight
			currentTier = value.(uint64)
			return false
		}
		poolTier.rewardCacheOf(currentTier).Iterate(startHeight, membershipUpdateHeight, func(height uint64, value interface{}) bool {
			reward := value.(uint64)
			self.rewardCache.Set(height, reward)
			return false
		})
		currentTier = value.(uint64)
		if currentTier == 0 {
			self.rewardCache.Set(membershipUpdateHeight, uint64(0))
		} else {
			self.rewardCache.Set(membershipUpdateHeight, poolTier.CurrentReward(currentTier, membershipUpdateHeight))
		}
		startHeight = membershipUpdateHeight
		currentTier = value.(uint64)
		return false
	})

	// take account of tier reward changes after the last tier membership change
	if currentTier == 0 {
		return
	}
	poolTier.rewardCacheOf(currentTier).Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		reward := value.(uint64)
		self.rewardCache.Set(height, reward)
		return false
	})
}

func setInRange(currentlyInRange bool, targetInRange bool) bool {
	if currentlyInRange != targetInRange {
		return targetInRange
	}
	panic(addDetailToError(
		errInvalidTickCross,
		ufmt.Sprintf("staker.gno__tickCrossesToEligibleIntervals() || currentlyInRange(%t) is already equal with targetInRange(%t)", currentlyInRange, targetInRange),
	))
}

func (self *Pool) TickCrossesToEligibleIntervals(
	tickUpperCrosses []int64,
	tickLowerCrosses []int64,
	currentlyInRange bool,
	startHeight,
	finalHeight uint64,
	f func(startHeight, endHeight uint64, stakedLiquidity *u256.Uint)
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

func (self *Pool) TickCrossesToInternalReward(tickUpperCrosses []int64, tickLowerCrosses []int64, currentlyInRange bool, deposit *Deposit) ([]uint64, []uint64) {
	if len(intervals) == 0 {
		return nil, nil
	}

	rewards := make([]uint64, len(deposit.warmups))
	penalties := make([]uint64, len(deposit.warmups))
	for i := 0; i < len(deposit.warmups); i++ {
		rewards[i] = 0
		penalties[i] = 0
	}
	
	positionLiquidity := deposit.liquidity
	self.rewardCache.EligibleIntervalsToReward(intervals, deposit, func(warmupIndex int, warmup Warmup, blockNumber uint64, stakedLiquidity *u256.Uint, poolRewardI interface{}) {
		poolReward := poolRewardI.(uint64)
		currentReward, currentPenalty := warmup.CalculateReward(blockNumber, poolReward, positionLiquidity, stakedLiquidity)
		rewards[warmupIndex] += currentReward
		penalties[warmupIndex] += currentPenalty
	})

	return rewards, penalties
}

func (self *Pool) modifyDeposit(tokenId uint64, liquidity *i256.Int, currentHeight uint64) {
	// update staker side pool info
	lastStakedLiquidity := self.CurrentStakedLiquidity(currentHeight)
	self.stakedLiquidity.Set(currentHeight, liquidityMathAddDelta(lastStakedLiquidity, liquidity))
}


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