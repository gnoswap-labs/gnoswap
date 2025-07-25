package staker

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

const (
	AllTierCount = 4 // 0, 1, 2, 3
	Tier1        = 1
	Tier2        = 2
	Tier3        = 3
)

// 100%, 0%, 0% if no tier2 and tier3
// 80%, 0%, 20% if no tier2
// 70%, 30%, 0% if no tier3
// 50%, 30%, 20% if has tier2 and tier3
type TierRatio struct {
	Tier1 uint64
	Tier2 uint64
	Tier3 uint64
}

// TierRatioFromCounts calculates the ratio distribution for each tier based on pool counts.
//
// Parameters:
// - tier1Count (uint64): Number of pools in tier 1.
// - tier2Count (uint64): Number of pools in tier 2.
// - tier3Count (uint64): Number of pools in tier 3.
//
// Returns:
// - TierRatio: The ratio distribution across tier 1, 2, and 3, scaled up by 100.
func TierRatioFromCounts(tier1Count, tier2Count, tier3Count uint64) TierRatio {
	// tier1 always exists
	if tier2Count == 0 && tier3Count == 0 {
		return TierRatio{
			Tier1: 100,
			Tier2: 0,
			Tier3: 0,
		}
	}
	if tier2Count == 0 {
		return TierRatio{
			Tier1: 80,
			Tier2: 0,
			Tier3: 20,
		}
	}
	if tier3Count == 0 {
		return TierRatio{
			Tier1: 70,
			Tier2: 30,
			Tier3: 0,
		}
	}
	return TierRatio{
		Tier1: 50,
		Tier2: 30,
		Tier3: 20,
	}
}

// Get returns the ratio(scaled up by 100) for the given tier.
func (self *TierRatio) Get(tier uint64) uint64 {
	switch tier {
	case Tier1:
		return self.Tier1
	case Tier2:
		return self.Tier2
	case Tier3:
		return self.Tier3
	default:
		panic(makeErrorWithDetails(
			errInvalidPoolTier, ufmt.Sprintf("unsupported tier(%d)", tier)))
	}
}

// PoolTier manages pool counts, ratios, and rewards for different tiers.
//
// Fields:
// - membership: Tracks which tier a pool belongs to (poolPath -> blockNumber -> tier).
//
// Methods:
// - CurrentCount: Returns the current count of pools in a tier at a specific height.
// - CurrentRatio: Returns the current ratio for a tier at a specific height.
// - CurrentTier: Returns the tier of a specific pool at a given height.
// - CurrentReward: Retrieves the reward for a tier at a specific height.
// - changeTier: Updates the tier of a pool and recalculates ratios.
type PoolTier struct {
	membership *avl.Tree // poolPath -> tier(1, 2, 3)

	tierRatio TierRatio

	lastRewardCacheHeight int64

	currentEmission int64

	// returns current emission.
	getEmission func() int64

	// returns a list of halving blocks within the interval [start, end) in ascending order
	// there MUST NOT be any emission amount change between start and end - those had to be handled by the stakerEmissionChangeCallback.
	getHalvingBlocksInRange func(start, end int64) ([]int64, []int64)
}

// NewPoolTier creates a new PoolTier instance with single initial 1 tier pool.
//
// Parameters:
// - pools: The pool collection.
// - currentHeight: The current block height.
// - initialPoolPath: The path of the initial pool.
// - getEmission: A function that returns the current emission to the staker contract.
// - getHalvingBlocksInRange: A function that returns a list of halving blocks within the interval [start, end) in ascending order.
//
// Returns:
// - *PoolTier: The new PoolTier instance.
func NewPoolTier(pools *Pools, currentHeight int64, initialPoolPath string, getEmission func() int64, getHalvingBlocksInRange func(start, end int64) ([]int64, []int64)) *PoolTier {
	result := &PoolTier{
		membership:              avl.NewTree(),
		tierRatio:               TierRatioFromCounts(1, 0, 0),
		lastRewardCacheHeight:   currentHeight + 1,
		getEmission:             getEmission,
		getHalvingBlocksInRange: getHalvingBlocksInRange,
		currentEmission:         getEmission(),
	}

	pools.set(initialPoolPath, NewPool(initialPoolPath, currentHeight+1))
	result.changeTier(currentHeight+1, pools, initialPoolPath, 1)
	return result
}

// CurrentReward returns the current per-pool reward for the given tier.
func (self *PoolTier) CurrentReward(tier uint64) int64 {
	currentEmission := self.getEmission()
	return currentEmission * int64(self.tierRatio.Get(tier)) / int64(self.CurrentCount(tier)) / 100
}

// CurrentCount returns the current count of pools in the given tier.
func (self *PoolTier) CurrentCount(tier uint64) int {
	count := 0
	self.membership.Iterate("", "", func(key string, value any) bool {
		if value.(uint64) == tier {
			count++
		}
		return false
	})
	return count
}

// CurrentAllTierCounts returns the current count of pools in each tier.
func (self *PoolTier) CurrentAllTierCounts() []uint64 {
	count := make([]uint64, AllTierCount)
	self.membership.Iterate("", "", func(key string, value any) bool {
		count[value.(uint64)]++
		return false
	})
	return count
}

// CurrentTier returns the tier of the given pool.
func (self *PoolTier) CurrentTier(poolPath string) uint64 {
	tier, ok := self.membership.Get(poolPath)
	if !ok {
		return 0
	}
	return tier.(uint64)
}

// changeTier updates the tier of a pool, recalculates ratios, and applies
// updated per-pool reward to each of the pools.
func (self *PoolTier) changeTier(currentHeight int64, pools *Pools, poolPath string, nextTier uint64) {
	self.cacheReward(currentHeight, pools)
	// same as prev. no need to update
	currentTier := self.CurrentTier(poolPath)
	if currentTier == nextTier {
		// no change, return
		return
	}

	if nextTier == 0 {
		// removed from the tier
		self.membership.Remove(poolPath)
		pool, ok := pools.Get(poolPath)
		if !ok {
			panic("changeTier: pool not found")
		}
		// caching reward to 0
		pool.cacheReward(currentHeight, int64(0))
	} else {
		self.membership.Set(poolPath, nextTier)
	}

	counts := self.CurrentAllTierCounts()
	self.tierRatio = TierRatioFromCounts(counts[Tier1], counts[Tier2], counts[Tier3])

	currentEmission := self.getEmission()

	// Cache updated reward for each tiered pool
	self.membership.Iterate("", "", func(key string, value any) bool {
		pool, ok := pools.Get(key)
		if !ok {
			panic("changeTier: pool not found")
		}
		tier := value.(uint64)
		poolReward := currentEmission * int64(self.tierRatio.Get(tier)) / 100 / int64(counts[tier])
		pool.cacheReward(currentHeight, poolReward)
		return false
	})

	self.currentEmission = currentEmission
}

// cacheReward MUST be called before calculating any position reward
// cacheReward updates the reward cache for each pools, accounting for any halving event in between the last cached height and the current height.
func (self *PoolTier) cacheReward(currentHeight int64, pools *Pools) {
	lastHeight := self.lastRewardCacheHeight

	if currentHeight <= lastHeight {
		// no need to check
		return
	}

	// find halving blocks in range
	halvingBlocks, halvingEmissions := self.getHalvingBlocksInRange(lastHeight, currentHeight)

	if len(halvingBlocks) == 0 {
		self.applyCacheToAllPools(pools, currentHeight, self.currentEmission)
		return
	}

	for i, hvBlock := range halvingBlocks {
		emission := halvingEmissions[i]
		// caching: [lastHeight, hvBlock)
		self.applyCacheToAllPools(pools, hvBlock, emission)

		// halve emissions when halvingBlock is reached
		self.currentEmission = emission
	}

	// remaining range [lastHalvingBlock, currentHeight)
	self.applyCacheToAllPools(pools, currentHeight, self.currentEmission)

	// update lastRewardCacheHeight and currentEmission
	self.lastRewardCacheHeight = currentHeight
}

// applyCacheToAllPools applies the cached reward to all tiered pools.
func (self *PoolTier) applyCacheToAllPools(pools *Pools, currentBlock int64, emissionInThisInterval int64) {
	// calculate denominator and number of pools in each tier
	counts := self.CurrentAllTierCounts()

	// apply cache to all pools
	self.membership.Iterate("", "", func(key string, value any) bool {
		tierNum := value.(uint64)
		pool, ok := pools.Get(key)
		if !ok {
			return false
		}

		// real reward
		reward := emissionInThisInterval * int64(self.tierRatio.Get(tierNum)) / 100 / int64(counts[tierNum])
		// accumulate the reward for the interval (startBlock to endBlock) in the Pool
		pool.cacheInternalReward(currentBlock, reward)
		return false
	})
}

// IsInternallyIncentivizedPool returns true if the pool is in a tier.
func (self *PoolTier) IsInternallyIncentivizedPool(poolPath string) bool {
	return self.CurrentTier(poolPath) > 0
}

func (self *PoolTier) CurrentRewardPerPool(poolPath string) int64 {
	emission := self.getEmission()
	counts := self.CurrentAllTierCounts()
	tierNum := self.CurrentTier(poolPath)
	reward := emission * int64(self.tierRatio.Get(tierNum)) / 100 / int64(counts[tierNum])
	return reward
}
