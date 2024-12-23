package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"
)

// 100, 0, 0 if no tier2 and tier3
// 80, 0, 20 if no tier2
// 70, 30, 0 if no tier3
// 50, 30, 20 if has tier2 and tier3
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

func (self *PoolTier) LastCount(tier uint64, endHeight uint64) uint64 {
	tree := self.countOf(tier)
	count := uint64(0)
	tree.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		count = value.(uint64)
		return true
	})
	return count
}

func (self *PoolTier) LastRatio(tier uint64, endHeight uint64) uint64 {
	ratio := uint64(0)
	self.tierRatio.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		ratio = value.(*TierRatio).Get(tier)
		return true
	})
	return ratio
}

func (self *PoolTier) LastTier(poolPath string, endHeight uint64) uint64 {
	tier := uint64(0)
	poolTierMembershipI, ok := self.membership.Get(poolPath)
	if !ok {
		return tier
	}
	poolTierMembership := poolTierMembershipI.(*UintTree)
	poolTierMembership.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		tier = value.(uint64)
		return true
	})
	return tier
}

func (self *PoolTier) LastReward(tier uint64, endHeight uint64) uint64 {
	reward := self.rewardCacheOf(tier).Last(endHeight)
	if reward == nil {
		return uint64(0)
	}
	return reward.(uint64)
}

func (self *PoolTier) changeTier(poolPath string, nextTier uint64) {
	height := uint64(std.GetHeight())
	currentTier := self.LastTier(poolPath, height)
	if currentTier == nextTier {
		return
	}

	currentTierCount := uint64(0)
	if currentTier != 0 {
		currentTierCount = self.LastCount(currentTier, height) - 1
		self.countOf(currentTier).Set(height, currentTierCount)
	}

	nextTierLastCount := uint64(0)
	if nextTier != 0 {
		nextTierLastCount = self.LastCount(nextTier, height)
		self.countOf(nextTier).Set(height, nextTierLastCount+1)
	}

	self.membershipOf(poolPath).Set(height, nextTier)

	if currentTierCount == 0 || nextTierLastCount == 0 {
		// ratio changed
		newRatio := TierRatioFromCounts(self.LastCount(1, height), self.LastCount(2, height), self.LastCount(3, height))
		self.tierRatio.Set(height, newRatio)
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

func (self *PoolTier) IsInternallyIncentivizedPool(poolPath string) bool {
	return self.LastTier(poolPath, uint64(std.GetHeight())) != 0
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
	// count * (ratio * 100) updates
	currentCount := self.LastCount(tier, startHeight)
	currentRatio := self.LastRatio(tier, startHeight)
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	tierCountTree := self.countOf(tier)
	lastHeight := startHeight
	tierCountTree.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.tierRatio.Iterate(lastHeight, height, func(ratioHeight uint64, value interface{}) bool {
			currentRatio = value.(*TierRatio).Get(tier)
			update := currentCount * currentRatio
			if ratioHeight == lastHeight {
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
		updates = append(updates, currentCount*currentRatio)

		lastHeight = height

		return false
	})

	// take account of ratio changes after the last count change
	self.tierRatio.Iterate(lastHeight, endHeight, func(key uint64, value interface{}) bool {
		ratioHeight := key
		currentRatio = value.(*TierRatio).Get(tier)
		update := currentCount * currentRatio
		if ratioHeight == lastHeight {
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

func (self *PoolTier) cacheTierReward(tier uint64, startHeight, endHeight uint64, currentEmissionUpdateHeight uint64, currentEmissionUpdate uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	rewardCache := self.rewardCacheOf(tier)
	for i := 0; i < len(emissionUpdateHeights); i++ {
		heights, updates := self.TierDenominatorUpdates(tier, currentEmissionUpdateHeight, emissionUpdateHeights[i])
		for j := 0; j < len(heights); j++ {
			denominator := updates[j]
			reward := (currentEmissionUpdate * 100) / denominator
			rewardCache.Set(heights[j], reward)
		}
		currentEmissionUpdateHeight = emissionUpdateHeights[i]
		currentEmissionUpdate = emissionUpdates[i]
	}
}

func (self *PoolTier) cacheReward(endHeight uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64) {
	startHeight := *self.lastRewardCacheHeight

	for tier := uint64(1); tier <= 3; tier++ {
		self.cacheTierReward(tier, startHeight, endHeight, emissionUpdateHeights[0], emissionUpdates[0], emissionUpdateHeights[1:], emissionUpdates[1:])
	}
}