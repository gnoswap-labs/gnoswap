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
// - membership: Tracks which tier a pool belongs to (poolPath -> tier).
// - tierRatio: Current ratio distribution for each tier.
// - lastRewardCacheHeight: Last height when reward cache was updated.
// - lastAccumulatedReward: Last recorded accumulated reward from getAccumulatedReward.
// - getAccumulatedReward: Function that returns the current accumulated reward distributed to staker.
//
// Methods:
// - CurrentCount: Returns the current count of pools in a tier.
// - CurrentTier: Returns the tier of a specific pool.
// - changeTier: Updates the tier of a pool and recalculates ratios.
type PoolTier struct {
	membership *avl.Tree // poolPath -> tier(1, 2, 3)

	tierRatio TierRatio

	lastRewardCacheHeight int64

	lastAccumulatedReward int64

	// returns current accumulated reward distributed to staker.
	getAccumulatedReward func() int64
}

// NewPoolTier creates a new PoolTier instance with single initial 1 tier pool.
//
// Parameters:
// - pools: The pool collection.
// - currentHeight: The current block height.
// - initialPoolPath: The path of the initial pool.
// - getAccumulatedReward: A function that returns the current accumulated reward distributed to staker.
//
// Returns:
// - *PoolTier: The new PoolTier instance.
func NewPoolTier(
	pools *Pools,
	currentHeight int64,
	initialPoolPath string,
	getAccumulatedReward func() int64,
) *PoolTier {
	result := &PoolTier{
		membership:            avl.NewTree(),
		tierRatio:             TierRatioFromCounts(1, 0, 0),
		lastRewardCacheHeight: currentHeight + 1,
		lastAccumulatedReward: getAccumulatedReward(),
		getAccumulatedReward:  getAccumulatedReward,
	}

	pools.set(initialPoolPath, NewPool(initialPoolPath, currentHeight+1))
	result.changeTier(currentHeight+1, pools, initialPoolPath, 1)
	return result
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

	// Recalculate tier ratios based on new pool counts
	counts := self.CurrentAllTierCounts()
	self.tierRatio = TierRatioFromCounts(counts[Tier1], counts[Tier2], counts[Tier3])

	// Note: Reward distribution will be handled by next cacheReward() call
	// which will calculate proper reward distribution based on new tier ratios
}

// cacheReward MUST be called before calculating any position reward
// cacheReward updates the reward cache for each pools based on accumulated reward difference
func (self *PoolTier) cacheReward(currentHeight int64, pools *Pools) {
	lastHeight := self.lastRewardCacheHeight

	if currentHeight <= lastHeight {
		// no need to check
		return
	}

	// Get current accumulated reward
	currentAccumulatedReward := self.getAccumulatedReward()

	// Calculate the reward difference since last cache
	rewardDiff := currentAccumulatedReward - self.lastAccumulatedReward

	// Apply the reward difference to all pools
	self.applyCacheToAllPools(pools, currentHeight, rewardDiff)

	// Update tracking values
	self.lastRewardCacheHeight = currentHeight
	self.lastAccumulatedReward = currentAccumulatedReward
}

// applyCacheToAllPools applies the reward difference to all tiered pools based on tier ratios.
func (self *PoolTier) applyCacheToAllPools(pools *Pools, currentBlock int64, totalRewardDiff int64) {
	// calculate denominator and number of pools in each tier
	counts := self.CurrentAllTierCounts()

	// If no reward difference, still call cacheInternalReward to update heights
	if totalRewardDiff <= 0 {
		self.membership.Iterate("", "", func(key string, value any) bool {
			pool, ok := pools.Get(key)
			if !ok {
				return false
			}
			// Pass 0 reward to update heights only
			pool.cacheInternalReward(currentBlock, 0)
			return false
		})
		return
	}

	// apply cache to all pools
	self.membership.Iterate("", "", func(key string, value any) bool {
		tierNum := value.(uint64)
		pool, ok := pools.Get(key)
		if !ok {
			return false
		}

		// Calculate this pool's share of the total reward difference
		// poolReward = totalRewardDiff * tierRatio / 100 / poolCount
		poolReward := totalRewardDiff * int64(self.tierRatio.Get(tierNum)) / 100 / int64(counts[tierNum])

		// accumulate the reward for this pool
		pool.cacheInternalReward(currentBlock, poolReward)
		return false
	})
}

// IsInternalIncentivizedPool returns true if the pool is in a tier.
func (self *PoolTier) IsInternalIncentivizedPool(poolPath string) bool {
	return self.CurrentTier(poolPath) > 0
}
