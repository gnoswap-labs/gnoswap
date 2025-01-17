package staker

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v1/emission"
)

const (
	TierRatioLCM = 8400 // LCM(20, 30, 50, 70, 80, 100)
	AllTierCount = 4    // 0, 1, 2, 3
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

// RewardDenominator[i] = TierCount[i] * TierRatioLCM / (TierRatio[i] * 100)
// TierReward[i] = Emission * TierRatioLCM / RewardDenominator[i] / 100
func (self *TierRatio) IntoRewardDenominators(counts []uint64) []uint64 {
	if len(counts) != AllTierCount {
		panic(addDetailToError(
			errInvalidPoolTier, ufmt.Sprintf("invalid tier count length(%d)", len(counts))),
		)
	}

	println("\tIntoRewardDenominators : , All tier counts len : ", len(counts))
	result := make([]uint64, AllTierCount)
	for i := Tier1; i < AllTierCount; i++ {
		if counts[i] == 0 {
			result[i] = 0
		} else {
			result[i] = counts[i] * TierRatioLCM / (self.Get(uint64(i)))
		}
		println("\t[", i, "] : ", counts[i], ", ratio : ", self.Get(uint64(i)), ", result : ", result[i])
	}
	return result
}

func ApplyDenominator(emission uint64, denominator uint64) uint64 {
	println("\tApplyDenominator : emission : ", emission, ", denominator : ", denominator, ", return : ", emission*TierRatioLCM/denominator/100)
	if denominator == 0 {
		return 0
	}

	return emission * TierRatioLCM / denominator / 100
}

func (self *TierRatio) Get(tier uint64) uint64 {
	switch tier {
	case Tier1:
		return self.Tier1
	case Tier2:
		return self.Tier2
	case Tier3:
		return self.Tier3
	default:
		panic(addDetailToError(
			errInvalidPoolTier, ufmt.Sprintf("unsupported tier(%d)", tier)))
	}
}

// PoolTier manages pool counts, ratios, and rewards for different tiers.
//
// Fields:
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
	membership *avl.Tree // poolPath -> tier(1, 2, 3)

	tierRatio *TierRatio

	// rewardCache is used to calculate internal reward for each tier
	// rewardCache = (per block emission) / (number of pools in tier) * (tier's ratio)
	// rewardCache           [4]*RewardCacheTree // blockNumber -> uint64
	lastRewardCacheHeight int64

	currentEmission uint64

	// returns current emission.
	getEmission func() uint64

	// returns a list of halving blocks within the interval [start, end) in ascending order
	// there MUST NOT be any emission amount change between start and end - those had to be handled by the CallbackStakerEmissionChange. 
	getHalvingBlocksInRange func(start, end int64) ([]int64, []uint64)

}

func NewPoolTier(pools *Pools, currentHeight int64, initialPoolPath string, getEmission func() uint64, getHalvingBlocksInRange func(start, end int64) ([]int64, []uint64)) *PoolTier {
	result := &PoolTier{
		membership:            avl.NewTree(),
		tierRatio:             TierRatioFromCounts(1, 0, 0),
		lastRewardCacheHeight: currentHeight + 1,
		getEmission:           getEmission,
		getHalvingBlocksInRange: getHalvingBlocksInRange,
		currentEmission:       getEmission(),
	}

	result.createPool(pools, initialPoolPath, 1, 0/*FIXME XXX: WE NEED TO GET THE TICK*/, currentHeight+1)
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

func (self *PoolTier) createPool(pools *Pools, poolPath string, initialTier uint64, initialTick int32, currentHeight int64) {
	_ = pools.GetOrCreate(poolPath, initialTick)

	self.changeTier(currentHeight, pools, poolPath, initialTier)
}

func (self *PoolTier) CurrentReward(tier uint64) uint64 {
	currentEmission := self.getEmission()
	return currentEmission * self.tierRatio.Get(tier) / uint64(self.CurrentCount(tier)) / 100
}

func (self *PoolTier) CurrentCount(tier uint64) int {
	count := 0
	self.membership.Iterate("", "", func(key string, value interface{}) bool {
		if value.(uint64) == tier {
			count++
		}
		return false
	})
	return count
}

func (self *PoolTier) CurrentAllTierCounts() []uint64 {
	count := make([]uint64, AllTierCount)
	self.membership.Iterate("", "", func(key string, value interface{}) bool {
		count[value.(uint64)]++
		return false
	})
	return count
}

func (self *PoolTier) CurrentTier(poolPath string) uint64 {
	tier, ok := self.membership.Get(poolPath)
	if !ok {
		return 0
	}
	return tier.(uint64)
}

func (self *PoolTier) changeTier(currentHeight int64, pools *Pools, poolPath string, nextTier uint64) {
	// TODO:
	// poolPath validation check

	println("[", currentHeight, "] changeTier Start -> poolPath : ", poolPath, ", nextTier : ", nextTier)
	self.cacheReward(currentHeight, pools)

	// same as prev. no need to update
	currentTier := self.CurrentTier(poolPath)
	if currentTier == nextTier {
		return
	}

	if nextTier == 0 {
		self.membership.Remove(poolPath)
		_, ok := pools.Get(poolPath)
		if !ok {
			panic("changeTier: pool not found")
		}
	} else {
		self.membership.Set(poolPath, nextTier)
	}

	counts := self.CurrentAllTierCounts()
	self.tierRatio = TierRatioFromCounts(counts[Tier1], counts[Tier2], counts[Tier3])

	rewardDenominators := self.tierRatio.IntoRewardDenominators(counts)

	// We only care about the current emission update at the current height.
	// Any emission update were already handled by the cacheReward() at the start of changeTier().
	currentEmission := self.getEmission()

	self.membership.Iterate("", "", func(key string, value interface{}) bool {
		pool, ok := pools.Get(key)
		if !ok {
			panic("changeTier: pool not found")
		}
		pool.cacheReward(currentHeight, currentHeight, ApplyDenominator(currentEmission, rewardDenominators[value.(uint64)]))
		return false
	})

	self.currentEmission = currentEmission
}

func CalculateTierReward(currentEmission uint64, tierRatio *TierRatio, tier uint64, poolCount uint64) uint64 {
	return currentEmission * tierRatio.Get(tier) / 100 / poolCount
}

// cacheReward MUST be called before calculating any position reward
// There MUST be no ratio/count/tier change during the emissionUpdates
// (due to calling cacheReward() at the start of changeTier(), this holds true).
func (self *PoolTier) cacheReward(currentHeight int64, pools *Pools) {
	lastHeight := self.lastRewardCacheHeight
	println("[[[cacheReward]]] currentHeight : ", currentHeight, ", lastHeight : ", lastHeight)

	if currentHeight <= lastHeight {
		// no need to check
		return
	}

	// find halving blocks in range
	halvingBlocks, halvingEmissions := self.getHalvingBlocksInRange(lastHeight, currentHeight)
	println("[[[cacheReward]]] halvingBlocks : ", halvingBlocks)
	println("[[[cacheReward]]] halvingEmissions : ", halvingEmissions)

	cursor := lastHeight
	currentEmission := self.currentEmission

	println("[[[cacheReward]]] cursor : ", cursor)
	println("[[[cacheReward]]] currentEmission : ", currentEmission)

	for i, hvBlock := range halvingBlocks {
		/*
		if hvBlock < cursor {
			continue
		}

		if hvBlock >= currentHeight {
			break
		}
		*/

		// caching: [cursor, hvBlock)
		startBlock := cursor
		endBlock := hvBlock
		if endBlock > startBlock {
			println("[[[cacheReward]]] applyCacheToAllPools Start halvingBlock : ", hvBlock)
			self.applyCacheToAllPools(pools, startBlock, endBlock, currentEmission)
			println("[[[cacheReward]]] applyCacheToAllPools End halvingBlock : ", hvBlock)
			cursor = endBlock
		}

		// halve emissions when halvingBlock is reached
		currentEmission = halvingEmissions[i]
	}

	// remaining range [cursor, currentHeight)
	if cursor < currentHeight {
		println("###### applyCacheToAllPools")
		self.applyCacheToAllPools(pools, cursor, currentHeight, currentEmission)
		println("###### applyCacheToAllPools done")
		cursor = currentHeight
	}

	// update lastRewardCacheHeight and currentEmission
	self.lastRewardCacheHeight = currentHeight
	println("[[[cacheReward]]] lastRewardCacheHeight set : ", self.lastRewardCacheHeight)
	self.currentEmission = currentEmission
}

func (self *PoolTier) applyCacheToAllPools(pools *Pools, startBlock, endBlock int64, emissionInThisInterval uint64) {
	println("###### applyCacheToAllPools startBlock : ", startBlock, ", endBlock : ", endBlock, ", emissionInThisInterval : ", emissionInThisInterval)
	if startBlock >= endBlock {
		return
	}

	// calculate denominator and number of pools in each tier
	counts := self.CurrentAllTierCounts()
	denominators := self.tierRatio.IntoRewardDenominators(counts)

	// apply cache to all pools
	self.membership.Iterate("", "", func(key string, value interface{}) bool {
		tierNum := value.(uint64)
		pool, ok := pools.Get(key)
		if !ok {
			return false
		}

		// real reward
		reward := ApplyDenominator(emissionInThisInterval, denominators[tierNum])
		println("###### applyCacheToAllPools reward : ", reward)
		// accumulate the reward for the interval (startBlock to endBlock) in the Pool
		// TODO: the startBlock in this scope and the pool's lastRewardCacheHeight MUST be the same. They should be merged into the one variable(preferrably by passing StartHeight explicitly)
		pool.cacheInternalReward(endBlock, reward)
		return false
	})
}

func (self *PoolTier) IsInternallyIncentivizedPool(currentHeight int64, poolPath string) bool {
	return self.CurrentTier(poolPath) > 0
}

// Called when msPerBlock is changed or staker emission % is changed.
// This does not take account of halving.
func CallbackStakerEmissionChange(amount uint64) {
	poolTier.cacheReward(std.GetHeight(), pools)
}
