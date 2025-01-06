package staker

import (
	"math"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

const TierRatioLCM = 8400

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
// - *TierRatio: The ratio distribution across tier 1, 2, and 3.
func TierRatioFromCounts(tier1Count, tier2Count, tier3Count uint64) *TierRatio {
	// tier1 always exists
	if tier2Count == 0 && tier3Count == 0 {
		return &TierRatio{
			Tier1: 100,
			Tier2: 0,
			Tier3: 0,
		}
	}
	if tier2Count == 0 {
		return &TierRatio{
			Tier1: 80,
			Tier2: 0,
			Tier3: 20,
		}
	}
	if tier3Count == 0 {
		return &TierRatio{
			Tier1: 70,
			Tier2: 30,
			Tier3: 0,
		}
	}
	return &TierRatio{
		Tier1: 50,
		Tier2: 30,
		Tier3: 20,
	}
}

func (self *TierRatio) Get(tier uint64) uint64 {
	switch tier {
	case 1:
		return self.Tier1
	case 2:
		return self.Tier2
	case 3:
		return self.Tier3
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("0 staker.gno__tierRatio() || tier(%d) is not valid", tier),
		))
	}
}

// PoolTier manages pool counts, ratios, and rewards for different tiers.
//
// Fields:
// - count: Stores the number of pools for each tier (blockNumber -> pool count).
// - tierRatio: Stores the ratio distribution for each tier (blockNumber -> TierRatio).
// - membership: Tracks which tier a pool belongs to (poolPath -> blockNumber -> tier).
// - rewardCache: Stores cached rewards for each tier (blockNumber -> reward).
//
// Methods:
// - CurrentCount: Returns the current count of pools in a tier at a specific height.
// - CurrentRatio: Returns the current ratio for a tier at a specific height.
// - CurrentTier: Returns the tier of a specific pool at a given height.
// - CurrentReward: Retrieves the reward for a tier at a specific height.
// - changeTier: Updates the tier of a pool and recalculates ratios.
type PoolTier struct {
	count      [4]*UintTree // blockNumber -> uint64 poolCount
	tierRatio  *UintTree    // blockNumber -> TierRatio
	membership *avl.Tree    // poolPath -> blockNumber -> tier(0(deleted), 1, 2, 3)

	// rewardCache is used to calculate internal reward for each tier
	// rewardCache = (per block emission) / (number of pools in tier) * (tier's ratio)
	rewardCache           [4]*RewardCacheTree // blockNumber -> uint64
	lastRewardCacheHeight *uint64
}

func NewPoolTier(currentHeight uint64, poolPath string) *PoolTier {
	result := &PoolTier{
		count: [4]*UintTree{
			nil,
			NewUintTree(),
			NewUintTree(),
			NewUintTree(),
		},
		tierRatio:  NewUintTree(),
		membership: avl.NewTree(),
		rewardCache: [4]*RewardCacheTree{
			nil,
			NewRewardCacheTree(),
			NewRewardCacheTree(),
			NewRewardCacheTree(),
		},
		lastRewardCacheHeight: &currentHeight,
	}
	result.count[1].Set(currentHeight, uint64(1))
	result.count[2].Set(currentHeight, uint64(0))
	result.count[3].Set(currentHeight, uint64(0))
	result.tierRatio.Set(currentHeight, TierRatioFromCounts(uint64(1), uint64(0), uint64(0)))
	result.membershipOf(poolPath).Set(currentHeight, uint64(1))
	return result
}

func (self *PoolTier) membershipOf(poolPath string) *UintTree {
	v, ok := self.membership.Get(poolPath)
	if !ok {
		tree := NewUintTree()
		self.membership.Set(poolPath, tree)
		return tree
	}
	return v.(*UintTree)
}

func (self *PoolTier) CurrentCount(tier uint64, currentHeight uint64) uint64 {
	tree := self.countOf(tier)
	countI, ok := tree.Get(currentHeight)
	if ok {
		return countI.(uint64)
	}
	count := uint64(0)
	tree.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		count = value.(uint64)
		return true
	})
	return count
}

func (self *PoolTier) CurrentRatio(tier uint64, currentHeight uint64) uint64 {
	ratioI, ok := self.tierRatio.Get(currentHeight)
	if ok {
		return ratioI.(*TierRatio).Get(tier)
	}
	ratio := uint64(0)
	self.tierRatio.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		ratio = value.(*TierRatio).Get(tier)
		return true
	})
	return ratio
}

func (self *PoolTier) CurrentTier(poolPath string, currentHeight uint64) uint64 {
	tier := uint64(0)
	poolTierMembershipI, ok := self.membership.Get(poolPath)
	if !ok {
		return tier
	}
	poolTierMembership := poolTierMembershipI.(*UintTree)
	poolTierMembership.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		tier = value.(uint64)
		return true
	})
	return tier
}

func (self *PoolTier) CurrentReward(tier uint64, currentHeight uint64) uint64 {
	reward := self.rewardCacheOf(tier).CurrentReward(currentHeight)
	if reward == nil {
		return uint64(0)
	}
	return reward.(uint64)
}

func (self *PoolTier) createPool(pools *Pools, poolPath string, initialTier uint64, currentHeight uint64) {
	_ = pools.GetOrCreate(poolPath)

	self.changeTier(currentHeight, poolPath, initialTier)
}

func (self *PoolTier) changeTier(currentHeight uint64, poolPath string, nextTier uint64) {
	currentTier := self.CurrentTier(poolPath, currentHeight)
	if currentTier == nextTier {
		return
	}

	currentTierCount := uint64(0)
	if currentTier != 0 {
		currentTierCount = self.CurrentCount(currentTier, currentHeight) - 1
		self.countOf(currentTier).Set(currentHeight, currentTierCount)
	}

	nextTierLastCount := uint64(0)
	if nextTier != 0 {
		nextTierLastCount = self.CurrentCount(nextTier, currentHeight)
		self.countOf(nextTier).Set(currentHeight, nextTierLastCount+1)
	}

	self.membershipOf(poolPath).Set(currentHeight, nextTier)

	if currentTierCount == 0 || nextTierLastCount == 0 {
		// ratio changed
		newRatio := TierRatioFromCounts(self.CurrentCount(1, currentHeight), self.CurrentCount(2, currentHeight), self.CurrentCount(3, currentHeight))
		self.tierRatio.Set(currentHeight, newRatio)
	}
}

func (self *PoolTier) countOf(tier uint64) *UintTree {
	switch tier {
	case 1:
		return self.count[1]
	case 2:
		return self.count[2]
	case 3:
		return self.count[3]
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("1 staker.gno__tier() || tier(%d) is not valid", tier),
		))
	}
}

func (self *PoolTier) IsInternallyIncentivizedPool(currentHeight uint64, poolPath string) bool {
	return self.CurrentTier(poolPath, currentHeight) != 0
}

func (self *PoolTier) TierMembershipUpdates(poolPath string, startHeight, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	poolTierMembership := self.membershipOf(poolPath)
	poolTierMembership.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		height := key
		heights = append(heights, height)
		updates = append(updates, value.(uint64))
		return false
	})

	return heights, updates
}

// Tiercountupdates returns
// 1. last update *before* the startHeight, which must include at least one update(the initial update set in NewPoolTier)
// 2. all updates between startHeight and endHeight, end exclusive
func (self *PoolTier) TierCountUpdates(tier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	self.countOf(tier).ReverseIterate(0, startHeight-1, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		return true
	})

	self.countOf(tier).Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		return false
	})

	return heights, updates
}

// TierRatioUpdates returns
// 1. last update *before* the startHeight, which must include at least one update(the initial update set in NewPoolTier)
// 2. all updates between startHeight and endHeight, end exclusive
func (self *PoolTier) TierRatioUpdates(tier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	self.tierRatio.ReverseIterate(0, startHeight-1, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(*TierRatio).Get(tier))
		return true
	})

	self.tierRatio.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(*TierRatio).Get(tier))
		return false
	})

	return heights, updates
}

func (self *PoolTier) rewardCacheOf(tier uint64) *RewardCacheTree {
	switch tier {
	case 1:
		return self.rewardCache[1]
	case 2:
		return self.rewardCache[2]
	case 3:
		return self.rewardCache[3]
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("2 staker.gno__rewardCacheOf() || tier(%d) is not valid", tier),
		))
	}
}

func (self *PoolTier) cachePerMembership(heights []uint64, updates []uint64, poolPath string, currentTier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	if currentTier != 0 {
		currentReward := self.rewardCacheOf(currentTier).CurrentReward(startHeight).(uint64)
		self.rewardCacheOf(currentTier).Iterate(startHeight, endHeight, func(tierRewardUpdateHeight uint64, value interface{}) bool {
			if len(heights) != 0 && heights[len(heights)-1] == startHeight {
				heights = heights[:len(heights)-1]
				updates = updates[:len(updates)-1]
			}
			heights = append(heights, startHeight)
			updates = append(updates, currentReward)
			startHeight = tierRewardUpdateHeight
			currentReward = value.(uint64)
			return false
		})
		if len(heights) != 0 && heights[len(heights)-1] == startHeight {
			heights = heights[:len(heights)-1]
			updates = updates[:len(updates)-1]
		}
		heights = append(heights, startHeight)
		updates = append(updates, currentReward)
	} else {
		if len(heights) != 0 && heights[len(heights)-1] == startHeight {
			heights = heights[:len(heights)-1]
			updates = updates[:len(updates)-1]
		}
		heights = append(heights, startHeight)
		updates = append(updates, uint64(0))
	}

	return heights, updates
}

// Returns list of tier membership updates between startHeight and endHeight
// 1. last update *before* the startHeight, which must include at least one update(the initial update set in NewPoolTier)
// 2. all updates between startHeight and endHeight, end exclusive
func (self *PoolTier) TierRewardUpdates(poolPath string, startHeight, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	currentTier := uint64(0)

	self.membershipOf(poolPath).ReverseIterate(0, startHeight, func(key uint64, value interface{}) bool {
		heights = append(heights, key)
		updates = append(updates, value.(uint64))
		return true
	})

	self.membershipOf(poolPath).Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		heights, updates = self.cachePerMembership(heights, updates, poolPath, currentTier, startHeight, endHeight)

		startHeight = key
		currentTier = value.(uint64)
		return false
	})

	if startHeight != endHeight {
		heights, updates = self.cachePerMembership(heights, updates, poolPath, currentTier, startHeight, endHeight)
	}

	return heights, updates
}

func nextHeightUpdateI(
	emissionUpdateHeights []uint64,
	emissionUpdateI int,
	countUpdateHeights []uint64,
	countUpdateI int,
	ratioUpdateHeights []uint64,
	ratioUpdateI int,
) (
	nextHeight uint64,
	nextEmissionUpdateI, nextCountUpdateI, nextRatioUpdateI int,
) {
	// Use a sentinel so that a “finished” slice does not interfere
	// with picking the minimum height from the remaining slices.

	// Safely fetch emissionUpdateHeight (or sentinel if out of range)
	var emissionUpdateHeight uint64
	if emissionUpdateI < len(emissionUpdateHeights) {
		emissionUpdateHeight = emissionUpdateHeights[emissionUpdateI]
	} else {
		emissionUpdateHeight = math.MaxUint64
	}

	// Safely fetch countUpdateHeight (or sentinel if out of range)
	var countUpdateHeight uint64
	if countUpdateI < len(countUpdateHeights) {
		countUpdateHeight = countUpdateHeights[countUpdateI]
	} else {
		countUpdateHeight = math.MaxUint64
	}

	// Safely fetch ratioUpdateHeight (or sentinel if out of range)
	var ratioUpdateHeight uint64
	if ratioUpdateI < len(ratioUpdateHeights) {
		ratioUpdateHeight = ratioUpdateHeights[ratioUpdateI]
	} else {
		ratioUpdateHeight = math.MaxUint64
	}

	nextEmissionUpdateI = emissionUpdateI
	nextCountUpdateI = countUpdateI
	nextRatioUpdateI = ratioUpdateI

	// Now pick the smallest among the three (which aren't sentinel).
	switch {
	case emissionUpdateHeight < countUpdateHeight && emissionUpdateHeight < ratioUpdateHeight:
		// Emission is the smallest
		nextHeight = emissionUpdateHeight
		nextEmissionUpdateI++
		return

	case countUpdateHeight < emissionUpdateHeight && countUpdateHeight < ratioUpdateHeight:
		// Count is the smallest
		nextHeight = countUpdateHeight
		nextCountUpdateI++
		return

	case ratioUpdateHeight < emissionUpdateHeight && ratioUpdateHeight < countUpdateHeight:
		// Ratio is the smallest
		nextHeight = ratioUpdateHeight
		nextRatioUpdateI++
		return

	// If there is a tie among any two or three of them, handle it similarly:
	case emissionUpdateHeight == countUpdateHeight &&
		emissionUpdateHeight < ratioUpdateHeight:
		// Tie between emission & count
		nextHeight = emissionUpdateHeight
		nextEmissionUpdateI++
		nextCountUpdateI++
		return

	case emissionUpdateHeight == ratioUpdateHeight &&
		emissionUpdateHeight < countUpdateHeight:
		// Tie between emission & ratio
		nextHeight = emissionUpdateHeight
		nextEmissionUpdateI++
		nextRatioUpdateI++
		return

	case ratioUpdateHeight == countUpdateHeight &&
		ratioUpdateHeight < emissionUpdateHeight:
		// Tie between ratio & count
		nextHeight = ratioUpdateHeight
		nextRatioUpdateI++
		nextCountUpdateI++
		return

	case emissionUpdateHeight == countUpdateHeight &&
		emissionUpdateHeight == ratioUpdateHeight &&
		emissionUpdateHeight != math.MaxUint64:
		// All three match
		nextHeight = emissionUpdateHeight
		nextEmissionUpdateI++
		nextCountUpdateI++
		nextRatioUpdateI++
		return
	default:
		panic("unreachable: all indices are exhausted")
	}
}

// emission update and tier membership update happens rarely.
// for each emission update(halving or ms per block change),
// iterate over denominator updates and cache reward for each block
func (self *PoolTier) cacheTierReward(tier uint64, startHeight, endHeight uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	rewardCache := self.rewardCacheOf(tier)

	countUpdateHeights, countUpdates := self.TierCountUpdates(tier, startHeight, endHeight)
	ratioUpdateHeights, ratioUpdates := self.TierRatioUpdates(tier, startHeight, endHeight)

	emissionUpdateI := 0
	countUpdateI := 0
	ratioUpdateI := 0

	currentHeight := startHeight

	currentEmission := emissionUpdates[emissionUpdateI]
	currentCount := countUpdates[countUpdateI]
	currentRatio := ratioUpdates[ratioUpdateI]

	for emissionUpdateI < len(emissionUpdateHeights) || countUpdateI < len(countUpdateHeights) || ratioUpdateI < len(ratioUpdateHeights) {
		currentHeight, emissionUpdateI, countUpdateI, ratioUpdateI = nextHeightUpdateI(
			emissionUpdateHeights,
			emissionUpdateI,
			countUpdateHeights,
			countUpdateI,
			ratioUpdateHeights,
			ratioUpdateI,
		)

		if emissionUpdateI < len(emissionUpdateHeights) {
			currentEmission = emissionUpdates[emissionUpdateI]
		}
		if countUpdateI < len(countUpdateHeights) {
			currentCount = countUpdates[countUpdateI]
		}
		if ratioUpdateI < len(ratioUpdateHeights) {
			currentRatio = ratioUpdates[ratioUpdateI]
		}

		if currentCount == 0 {
			rewardCache.Set(currentHeight, uint64(0))
		} else {
			reward := currentEmission * currentRatio / currentCount / 100
			rewardCache.Set(currentHeight, reward)
		}
	}
}

// cacheReward calculates and caches rewards for all tiers within a height range.
//
// Parameters:
// - endHeight (uint64): The end height for reward caching.
// - emissionUpdateHeights ([]uint64): Heights where emission updates occur.
// - emissionUpdates ([]uint64): Emission values for the corresponding update heights.
func (self *PoolTier) cacheReward(endHeight uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	startHeight := *self.lastRewardCacheHeight

	for tier := uint64(1); tier <= 3; tier++ {
		self.cacheTierReward(tier, startHeight, endHeight, emissionUpdateHeights, emissionUpdates)
	}
}
