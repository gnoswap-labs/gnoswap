package staker

import (
	"std"

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
			ufmt.Sprintf("staker.gno__tierRatio() || tier(%d) is not valid", tier),
		))
	}
}

type PoolTier struct {
	count [4]*UintTree // blockNumber -> uint64 poolCount

	tierRatio *UintTree // blockNumber -> TierRatio

	membership *avl.Tree // poolPath -> blockNumber -> tier(0(deleted), 1, 2, 3)

	// rewardCache is used to calculate internal reward for each tier
	// rewardCache = (per block emission) / (number of pools in tier) * (tier's ratio)
	rewardCache           [4]*RewardCacheTree // blockNumber -> uint64
	lastRewardCacheHeight *uint64
}

var poolTier *PoolTier = NewPoolTier(uint64(std.GetHeight()))

func NewPoolTier(currentHeight uint64) *PoolTier {
	return &PoolTier{
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
			ufmt.Sprintf("staker.gno__tier() || tier(%d) is not valid", tier),
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

func (self *PoolTier) TierDenominatorUpdates(tier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	// count * (8400 / tierRatio) updates
	currentCount := self.CurrentCount(tier, startHeight)
	currentRatio := self.CurrentRatio(tier, startHeight)
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	tierCountTree := self.countOf(tier)
	lastHeight := startHeight
	tierCountTree.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.tierRatio.Iterate(lastHeight, height, func(ratioHeight uint64, value interface{}) bool {
			currentRatio = value.(*TierRatio).Get(tier)
			if currentRatio == 0 {
				return false
			}
			update := currentCount * (TierRatioLCM / currentRatio)
			if ratioHeight == lastHeight && len(heights) > 0 {
				heights[len(heights)-1] = ratioHeight
				updates[len(updates)-1] = update
			} else {
				heights = append(heights, ratioHeight)
				updates = append(updates, update)
			}
			return false
		})

		currentCount = value.(uint64)
		heights = append(heights, height)
		updates = append(updates, currentCount*(TierRatioLCM/currentRatio))
		lastHeight = height

		return false
	})

	// take account of ratio changes after the last count change
	self.tierRatio.Iterate(lastHeight, endHeight, func(key uint64, value interface{}) bool {
		ratioHeight := key
		currentRatio = value.(*TierRatio).Get(tier)
		if currentRatio == 0 {
			return false
		}
		update := currentCount * (TierRatioLCM / currentRatio)
		if ratioHeight == lastHeight && len(heights) > 0 {
			heights[len(heights)-1] = ratioHeight
			updates[len(updates)-1] = update
		} else {
			heights = append(heights, ratioHeight)
			updates = append(updates, update)
		}
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
			ufmt.Sprintf("staker.gno__rewardCacheOf() || tier(%d) is not valid", tier),
		))
	}
}

// emission update and tier membership update happens rarely.
// for each emission update(halving or ms per block change),
// iterate over denominator updates and cache reward for each block
func (self *PoolTier) cacheTierReward(tier uint64, startHeight, endHeight uint64, currentEmissionUpdateHeight uint64, currentEmissionUpdate uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	rewardCache := self.rewardCacheOf(tier)

	heights, updates := self.TierDenominatorUpdates(tier, startHeight, currentEmissionUpdateHeight)
	for j := 0; j < len(heights); j++ {
		// denominator becomes 0 when pool is not incentivized
		if updates[j] == 0 {
			rewardCache.Set(heights[j], uint64(0))
			continue
		}
		denominator := updates[j] * 100
		reward := (currentEmissionUpdate * TierRatioLCM) / denominator
		rewardCache.Set(heights[j], reward)
	}

	for i := 0; i < len(emissionUpdateHeights); i++ {
		heights, updates := self.TierDenominatorUpdates(tier, currentEmissionUpdateHeight, emissionUpdateHeights[i])
		for j := 0; j < len(heights); j++ {
			if updates[j] == 0 {
				rewardCache.Set(heights[j], uint64(0))
				continue
			}
			denominator := updates[j] * 100
			reward := (currentEmissionUpdate * TierRatioLCM) / denominator
			rewardCache.Set(heights[j], reward)
		}
		currentEmissionUpdateHeight = emissionUpdateHeights[i]
		currentEmissionUpdate = emissionUpdates[i]
	}

	heights, updates = self.TierDenominatorUpdates(tier, currentEmissionUpdateHeight, endHeight)
	for j := 0; j < len(heights); j++ {
		if updates[j] == 0 {
			rewardCache.Set(heights[j], uint64(0))
			continue
		}
		denominator := updates[j] * 100
		reward := (currentEmissionUpdate * TierRatioLCM) / denominator
		rewardCache.Set(heights[j], reward)
	}
}

func (self *PoolTier) cacheReward(endHeight uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	startHeight := *self.lastRewardCacheHeight

	for tier := uint64(1); tier <= 3; tier++ {
		self.cacheTierReward(tier, startHeight, endHeight, emissionUpdateHeights[0], emissionUpdates[0], emissionUpdateHeights[1:], emissionUpdates[1:])
	}
}
