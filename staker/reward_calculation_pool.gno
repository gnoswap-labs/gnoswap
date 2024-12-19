package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	pn "gno.land/r/gnoswap/v1/position"

	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
)

type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

var (
	pools = &Pools{
		tree: avl.NewTree(),
	}
)

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
}
		
func NewPool(poolPath string, currentHeight uint64) *Pool {
	return &Pool{
		poolPath: poolPath,
		stakedLiquidity: NewUintTree(),
		rewardCache: NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
		incentives: NewIncentives(currentHeight),
	}
}

func (self *Pool) LastStakedLiquidity(end uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, end, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) LastReward(endHeight uint64) uint64 {
	reward := self.rewardCache.Last(endHeight)
	if reward == nil {
		return uint64(0)
	}
	return reward.(uint64)
} 

// cacheReward() MUST be called before this function
func (self *Pool) IsExternallyIncentivizedPool(height uint64) bool {
	return len(self.incentives.LastReward(height)) > 0
}

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

func (self *Pool) cacheReward(poolTier *PoolTier, endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	currentTier := poolTier.LastTier(self.poolPath, startHeight)
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
			self.rewardCache.Set(membershipUpdateHeight, poolTier.LastReward(currentTier, membershipUpdateHeight))
		}
		startHeight = membershipUpdateHeight
		currentTier = value.(uint64)
		return false
	})

	// take account of tier reward changes after the last tier membership change
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
	tickUpperCrossHeights []uint64,
	tickUpperCrossZeroForOnes []bool,
	tickLowerCrossHeights []uint64,
	tickLowerCrossZeroForOnes []bool,
	currentlyInRange bool,
	startHeight,
	finalHeight uint64,
) []Interval {
	intervals := make([]Interval, 0, len(tickUpperCrossHeights)+len(tickLowerCrossHeights))

	// enter/exit event MUST appear alternatively
	// note that zeroForOne is true when backward(from upper to lower)
	for len(tickUpperCrossHeights) != 0 || len(tickLowerCrossHeights) != 0 {
		upperRemains := len(tickUpperCrossHeights) != 0
		lowerRemains := len(tickLowerCrossHeights) != 0

		if upperRemains {
			currentUpperTickCrossHeight := tickUpperCrossHeights[0]
			doUpper := !lowerRemains
			if lowerRemains {
				doUpper = currentUpperTickCrossHeight < tickLowerCrossHeights[0]
			}
			if doUpper {
				if tickUpperCrossZeroForOnes[0] {
					// enter range, backward transition at the upper tick.
					currentlyInRange = setInRange(currentlyInRange, true)
					startHeight = currentUpperTickCrossHeight
				} else {
					// exit range, forward transition at the upper tick.
					currentlyInRange = setInRange(currentlyInRange, false)
					stakedLiquidity := self.LastStakedLiquidity(startHeight)
					endHeight := currentUpperTickCrossHeight

					intervals = appendIntervals(intervals, self.StakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
				}
				tickUpperCrossHeights = tickUpperCrossHeights[1:]
				tickUpperCrossZeroForOnes = tickUpperCrossZeroForOnes[1:]
				continue
			}
		}

		if lowerRemains {
			currentLowerTickCrossHeight := tickLowerCrossHeights[0]
			doLower := !upperRemains
			if upperRemains {
				doLower = currentLowerTickCrossHeight < tickUpperCrossHeights[0]
			}
			if doLower {
				if tickLowerCrossZeroForOnes[0] {
					// exit range, backward transition at the lower tick.
					currentlyInRange = setInRange(currentlyInRange, false)
					stakedLiquidity := self.LastStakedLiquidity(startHeight)
					endHeight := currentLowerTickCrossHeight

					intervals = appendIntervals(intervals, self.StakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
				} else {
					// enter range, forward transition at the lower tick.
					currentlyInRange = setInRange(currentlyInRange, true)
					startHeight = currentLowerTickCrossHeight
				}
				tickLowerCrossHeights = tickLowerCrossHeights[1:]
				tickLowerCrossZeroForOnes = tickLowerCrossZeroForOnes[1:]
				continue
			}
		}

		// The price has been passed through the whole position range
		// canceles each other, remaining outrange, skip.
		tickUpperCrossHeights = tickUpperCrossHeights[1:]
		tickLowerCrossHeights = tickLowerCrossHeights[1:]
		tickUpperCrossZeroForOnes = tickUpperCrossZeroForOnes[1:]
		tickLowerCrossZeroForOnes = tickLowerCrossZeroForOnes[1:]
		continue
	}

	if currentlyInRange {
		// position remains in range, add the last interval
		stakedLiquidity := self.LastStakedLiquidity(startHeight)
		intervals = appendIntervals(intervals, self.StakedLiquidityUpdates, stakedLiquidity, startHeight, finalHeight)
	}

	return intervals
}

func (self *Pool) EligibleIntervalsToInternalReward(intervals []Interval, deposit *Deposit) ([]uint64, []uint64) {
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
	if pn.PositionIsInRange(tokenId) {
		lastStakedLiquidity := self.LastStakedLiquidity(currentHeight)
		self.stakedLiquidity.Set(currentHeight, liquidityMathAddDelta(lastStakedLiquidity, liquidity))
	}
}