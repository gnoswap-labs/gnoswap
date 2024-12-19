package staker

import (
	"math"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func EncodeUint(num uint64) string {
	// Convert the value to a decimal string.
	s := strconv.FormatUint(num, 10)

	// Zero-pad to a total length of 20 characters.
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return num
}

type UintTree struct {
	tree *avl.Tree
}

func NewUintTree() *UintTree {
	return &UintTree{
		tree: avl.NewTree(),
	}
}

func (self *UintTree) Get(key uint64) (interface{}, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key uint64, value interface{}) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *UintTree) Has(key uint64) bool {
	return self.tree.Has(EncodeUint(key))
}

func (self *UintTree) Remove(key uint64) {
	self.tree.Remove(EncodeUint(key))
}

func (self *UintTree) Iterate(start, end uint64, fn func(key uint64, value interface{}) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end uint64, fn func(key uint64, value interface{}) bool) {
	self.tree.ReverseIterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		return fn(DecodeUint(key), value)
	})
}

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
	count [3]*UintTree // blockNumber -> uint64 poolCount

	tierRatio *UintTree // blockNumber -> TierRatio

	membership *avl.Tree // poolPath -> blockNumber -> tier(0(deleted), 1, 2, 3)

	// rewardCache is used to calculate internal reward for each tier
	// rewardCache = (per block emission) / (number of pools in tier) * (tier's ratio)
	rewardCache           [3]*UintTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight *uint64
}

var poolTier *PoolTier = &PoolTier{
	count: [3]*UintTree{
		NewUintTree(),
		NewUintTree(),
		NewUintTree(),
	},
	tierRatio:  NewUintTree(),
	membership: avl.NewTree(),
	rewardCache: [3]*UintTree{
		NewUintTree(),
		NewUintTree(),
		NewUintTree(),
	},
	lastRewardCacheHeight: nil,
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

func (self *PoolTier) LastReward(tier uint64, endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	tree := self.rewardCacheOf(tier)
	tree.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
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
		return self.count[0]
	case 2:
		return self.count[1]
	case 3:
		return self.count[2]
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

func (self *PoolTier) rewardCacheOf(tier uint64) *UintTree {
	switch tier {
	case 1:
		return self.rewardCache[0]
	case 2:
		return self.rewardCache[1]
	case 3:
		return self.rewardCache[2]
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("staker.gno__rewardCacheOf() || tier(%d) is not valid", tier),
		))
	}
}

func (self *PoolTier) cacheTierReward(tier uint64, startHeight, endHeight uint64, emissionUpdateHeights []uint64, emissionUpdates []uint64, currentEmissionUpdateHeight uint64, currentEmissionUpdate uint64) {
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

func (self *PoolTier) cacheReward(endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	emissionUpdateHeights, emissionUpdates := gns.PerBlockMintUpdates(startHeight, endHeight)
	currentEmissionUpdateHeight, currentEmissionUpdate := gns.LastPerBlockMintUpdate(startHeight)

	for tier := uint64(1); tier <= 3; tier++ {
		self.cacheTierReward(tier, startHeight, endHeight, emissionUpdateHeights, emissionUpdates, currentEmissionUpdateHeight, currentEmissionUpdate)
	}
}

type Pool struct {
	// conceptually equal with Pool.liquidity but only for the staked positions
	// updated each time when the pool crosses a staked tick
	stakedLiquidity *UintTree // blockNumber -> *u256.Uint

	// cache of the internal reward for each pool in tier
	rewardCache           *UintTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight uint64

	externalIncentiveUpdate *UintTree // blockNumber -> *u256.Uint
}

func (self *Pool) LastStakedLiquidity(end uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, end, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) LastReward(endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	self.rewardCache.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *Pool) LastExternalIncentive() *u256.Uint {
	reward := u256.Zero()
	self.externalIncentiveUpdate.ReverseIterate(0, uint64(std.GetHeight()), func(key uint64, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *Pool) IsExternallyIncentivizedPool() bool {
	return !self.LastExternalIncentive().IsZero()
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

func (self *PoolTier) cachePoolReward(poolRewardCache *UintTree, poolPath string, endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	currentTier := self.LastTier(poolPath, startHeight)
	self.membershipOf(poolPath).Iterate(startHeight, endHeight, func(membershipUpdateHeight uint64, value interface{}) bool {
		if currentTier == 0 {
			// ignore reward updates
			startHeight = membershipUpdateHeight
			currentTier = value.(uint64)
			return false
		}
		self.rewardCacheOf(currentTier).Iterate(startHeight, membershipUpdateHeight, func(height uint64, value interface{}) bool {
			reward := value.(*u256.Uint)
			poolRewardCache.Set(height, reward)
			return false
		})
		currentTier = value.(uint64)
		if currentTier == 0 {
			poolRewardCache.Set(membershipUpdateHeight, u256.Zero())
		} else {
			poolRewardCache.Set(membershipUpdateHeight, self.LastReward(currentTier, membershipUpdateHeight))
		}
		startHeight = membershipUpdateHeight
		return false
	})

	// take account of tier reward changes after the last tier membership change
	self.rewardCacheOf(currentTier).Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		reward := value.(*u256.Uint)
		poolRewardCache.Set(height, reward)
		return false
	})
}

type interval struct {
	startHeight uint64
	endHeight   uint64
	value       *u256.Uint
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

func (pool *Pool) TickCrossesToEligibleIntervals(
	tickUpperCrossHeights []uint64,
	tickUpperCrossZeroForOnes []bool,
	tickLowerCrossHeights []uint64,
	tickLowerCrossZeroForOnes []bool,
	currentlyInRange bool,
	startHeight,
	finalHeight uint64,
) []interval {
	intervals := make([]interval, 0, len(tickUpperCrossHeights)+len(tickLowerCrossHeights))

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
					stakedLiquidity := pool.LastStakedLiquidity(startHeight)
					endHeight := currentUpperTickCrossHeight

					intervals = appendIntervals(intervals, pool.StakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
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
					stakedLiquidity := pool.LastStakedLiquidity(startHeight)
					endHeight := currentLowerTickCrossHeight

					intervals = appendIntervals(intervals, pool.StakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
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
		stakedLiquidity := pool.LastStakedLiquidity(startHeight)
		intervals = appendIntervals(intervals, pool.StakedLiquidityUpdates, stakedLiquidity, startHeight, finalHeight)
	}

	return intervals
}

func appendIntervals(intervals []interval, updatesFn func(uint64, uint64) ([]uint64, []*u256.Uint), value *u256.Uint, startHeight, endHeight uint64) []interval {
	heights, updates := updatesFn(startHeight, endHeight)

	if len(updates) == 0 {
		return append(intervals, interval{
			startHeight,
			endHeight,
			value,
		})
	}

	if heights[0] != startHeight {
		intervals = append(intervals, interval{
			startHeight: startHeight,
			endHeight:   heights[0],
			value:       value,
		})
		startHeight = heights[0]
		value = updates[0]
		heights = heights[1:]
		updates = updates[1:]
	}
	for i := 0; i < len(updates); i++ {
		intervals = append(intervals, interval{
			startHeight: startHeight,
			endHeight:   heights[i],
			value:       value,
		})
		startHeight = heights[i]
		value = updates[i]
	}
	intervals = append(intervals, interval{
		startHeight,
		endHeight,
		value,
	})

	return intervals
}

type Tick struct {
	id int32
	
	stakedLiquidityGross *u256.Uint

	stakedLiquidityDelta *i256.Int

	// Notes for future optimizations.
	//
	// During swap, the states with the number of ticks that has been crossed are updated to store cross information.
	// Considering one tick is ~0.01%, if there is a 0.5% price change for a single swap(in common max slippage setting),
	// 50 ticks are crossed and 50 state write has to be done.
	// Considering that this number is capped by the max slippage in most of the cases, the scalability might not be a problem.
	// If this turns out to cause a gas cost issue, you may consider batching the
	// multiple tick's cross state into single state, similar to tick bitmap.
	// e.g. instead of having avl.Tree for each tick as key, use a segment of 32 ticks as bulk key.
	// The value can be a 64-bit integer, where each 2-bit represents 00(no-update), 01(backward-cross), 10(forward-cross), 11(no-update).

	// block number -> zeroForOne
	cross *UintTree
}

func (self *Tick) crossInfo(startHeight, endHeight uint64) ([]uint64, []bool) {
	tickCrossHeights := make([]uint64, 0)
	tickCrossZeroForOnes := make([]bool, 0)

	self.cross.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		tickCrossHeights = append(tickCrossHeights, key)
		tickCrossZeroForOnes = append(tickCrossZeroForOnes, value.(bool))
		return false
	})

	return tickCrossHeights, tickCrossZeroForOnes
}

func (self *Tick) updateCross(blockNumber uint64, zeroForOne bool) {
	cross, ok := self.cross.Get(blockNumber)
	if !ok {
		self.cross.Set(blockNumber, zeroForOne)
	} else if cross != zeroForOne {
		self.cross.Remove(blockNumber)
	}
}

func (self *Tick) lastCross(endHeight uint64) bool {
	// There MUST be at least one cross, set when the position is staked
	cross := false
	self.cross.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		cross = value.(bool)
		return true
	})
	return cross
}

type Pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func (self *Pools) Get(poolPath string) *Pool {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__get() || poolPath(%s) does not exist", poolPath),
		))
	}
	return v.(*Pool)
}

func (self *Pools) Set(poolPath string, pool *Pool) {
	self.tree.Set(poolPath, pool)
}

func (self *Pools) Has(poolPath string) bool {
	return self.tree.Has(poolPath)
}

type Ticks struct {
	tree *UintTree // int32 tickId -> tick
}

func (self *Ticks) Get(tickId int32) *Tick {
	v, ok := self.tree.Get(uint64(tickId))
	if !ok {
		tick := &Tick{
			stakedLiquidityGross: u256.Zero(),
			stakedLiquidityDelta: i256.Zero(),
			cross:                NewUintTree(),
		}
		self.tree.Set(uint64(tickId), tick)
		return tick
	}
	return v.(*Tick)
}

func (self *Ticks) Set(tickId int32, tick *Tick) {
	if tick.stakedLiquidityGross.IsZero() {
		// TODO: check if this could cause memory leak of GC halt
		// because tick.cross being dropped may overload the VM GC
		self.tree.Remove(uint64(tickId))
		return
	}
	self.tree.Set(uint64(tickId), tick)
}

type Warmup struct {
	NextWarmupHeight uint64
	WarmupRatio      uint64
}

func DefaultWarmups(currentHeight uint64, avgBlockTimeInMs uint64) []Warmup {
	msInDay := uint64(86400000)
	blocksInDay := msInDay / uint64(avgBlockTimeInMs)
	blocksIn5Days := uint64(5 * blocksInDay)
	blocksIn10Days := uint64(10 * blocksInDay)
	blocksIn30Days := uint64(30 * blocksInDay)

	return []Warmup{
		{
			NextWarmupHeight: currentHeight + blocksIn5Days,
			WarmupRatio:      30,
		},
		{
			NextWarmupHeight: currentHeight + blocksIn10Days,
			WarmupRatio:      50,
		},
		{
			NextWarmupHeight: currentHeight + blocksIn30Days,
			WarmupRatio:      70,
		},
		{
			NextWarmupHeight: math.MaxUint64,
			WarmupRatio:      100,
		},
	}
}

func (self *Deposit) findWarmup(height uint64) Warmup {
	for _, warmup := range self.warmups {
		if height < warmup.NextWarmupHeight {
			return warmup
		}
	}
	return self.warmups[len(self.warmups)-1]
}

func (self *Warmup) CalculateReward(blockNumber uint64, perBlockReward uint64) (uint64, uint64) {
	rewardRatio := self.WarmupRatio
	penaltyRatio := 100 - self.WarmupRatio
	totalReward := blockNumber * perBlockReward // TODO: check overflow
	return totalReward * rewardRatio / 100, totalReward * penaltyRatio / 100
}

func (self *Deposit) CalculateRewardForInterval(perBlockReward uint64, startHeight, endHeight uint64) (uint64, uint64) {
	if startHeight >= endHeight {
		return 0, 0
	}

	warmup := self.findWarmup(startHeight)
	if endHeight < warmup.NextWarmupHeight {
		return warmup.CalculateReward(endHeight-startHeight, perBlockReward)
	}

	warmupReward, warmupPenalty := warmup.CalculateReward(warmup.NextWarmupHeight-startHeight, perBlockReward)
	reward, penalty := self.CalculateRewardForInterval(perBlockReward, warmup.NextWarmupHeight, endHeight)
	return warmupReward + reward, warmupPenalty + penalty
}

func (self *Deposit) EligibleIntervalsToReward(intervals []interval, pool *Pool, endHeight uint64) (uint64, uint64) {
	totalReward := uint64(0)
	totalPenalty := uint64(0)

	for _, interval := range intervals {
		poolStakedLiquidity := interval.value
		poolReward := pool.LastReward(interval.startHeight)
		currentHeight := interval.startHeight
		pool.rewardCache.Iterate(interval.startHeight, interval.endHeight, func(height uint64, value interface{}) bool {
			perPositionReward := u256.Zero().Mul(poolReward, self.liquidity)
			perPositionReward = perPositionReward.Div(perPositionReward, poolStakedLiquidity)
			currentReward, currentPenalty := self.CalculateRewardForInterval(perPositionReward.Uint64(), currentHeight, height)

			totalReward += currentReward
			totalPenalty += currentPenalty

			currentHeight = height
			poolReward = value.(*u256.Uint)
			return false
		})
		perPositionReward := u256.Zero().Mul(poolReward, self.liquidity)
		perPositionReward = perPositionReward.Div(perPositionReward, poolStakedLiquidity)
		currentReward, currentPenalty := self.CalculateRewardForInterval(perPositionReward.Uint64(), currentHeight, interval.endHeight)
		totalReward += currentReward
		totalPenalty += currentPenalty
	}

	return totalReward, totalPenalty
}

var (
	pools = &Pools{
		tree: avl.NewTree(),
	}

	ticks = &Ticks{
		tree: NewUintTree(),
	}
)

func (self *Pool) modifyDeposit(tokenId uint64, liquidity *i256.Int, currentHeight uint64) {
	// update staker side pool info
	if pn.PositionIsInRange(tokenId) {
		lastStakedLiquidity := self.LastStakedLiquidity(currentHeight)
		self.stakedLiquidity.Set(currentHeight, liquidityMathAddDelta(lastStakedLiquidity, liquidity))
	}
}

func (self *Tick) modifyDepositLower(currentTick int32, liquidity *i256.Int) {
	// update staker side tick info
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	self.stakedLiquidityDelta = self.stakedLiquidityDelta.Add(self.stakedLiquidityDelta, liquidity)

	self.updateCross(uint64(std.GetHeight()), currentTick < self.id)
	// ticks.Set(self.id, self)
}

func (self *Tick) modifyDepositUpper(currentTick int32, liquidity *i256.Int) {
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	self.stakedLiquidityDelta = self.stakedLiquidityDelta.Sub(self.stakedLiquidityDelta, liquidity)

	self.updateCross(uint64(std.GetHeight()), currentTick < self.id)
	// ticks.Set(self.id, self)
}

func TickCrossHook(pools *Pools, ticks *Ticks) func(poolPath string, tickId int32, zeroForOne bool) {
	return func(poolPath string, tickId int32, zeroForOne bool) {
		initialized := pl.PoolGetTickInitialized(poolPath, tickId)
		if !initialized {
			return
		}
	
		tick := ticks.Get(tickId)
		pool := pools.Get(poolPath)
	
		blockNumber := uint64(std.GetHeight())
		tick.updateCross(blockNumber, zeroForOne)
	
		liquidityInRangeDelta := tick.stakedLiquidityDelta
		if zeroForOne {
			liquidityInRangeDelta = i256.Zero().Neg(liquidityInRangeDelta)
		}
		stakedLiquidity := pool.LastStakedLiquidity(blockNumber)
		pool.stakedLiquidity.Set(blockNumber, liquidityMathAddDelta(stakedLiquidity, liquidityInRangeDelta))
	
		// I'm not sure if this is needed. We may not need to update the pool info because the stakedLiquidity pointer itself has not changed.
		pools.Set(poolPath, pool)
	}
}

// liquidityMathAddDelta calculates the new liquidity by applying the delta liquidity to the current liquidity.
// If delta liquidity is negative, it subtracts the absolute value of delta liquidity from the current liquidity.
// If delta liquidity is positive, it adds the absolute value of delta liquidity to the current liquidity.
//
// Parameters:
// - x: The current liquidity as a uint256 value.
// - y: The delta liquidity as a signed int256 value.
//
// Returns:
// - The new liquidity as a uint256 value.
//
// Notes:
// - If `x` or `y` is nil, the function panics with an appropriate error message.
// - If `y` is negative, its absolute value is subtracted from `x`.
//   - The result must be less than `x`. Otherwise, the function panics to prevent underflow.
//
// - If `y` is positive, it is added to `x`.
//   - The result must be greater than or equal to `x`. Otherwise, the function panics to prevent overflow.
//
// - The function ensures correctness by validating the results of the arithmetic operations.
func liquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if x == nil || y == nil {
		panic(addDetailToError(
			errInvalidInput,
			"x or y is nil",
		))
	}

	var z *u256.Uint

	// Subtract or add based on the sign of y
	if y.Lt(i256.Zero()) {
		absDelta := y.Abs()
		z = new(u256.Uint).Sub(x, absDelta)
		if z.Gte(x) {
			panic(addDetailToError(
				errCalculationError,
				ufmt.Sprintf("Condition failed: (z must be < x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	} else {
		z = new(u256.Uint).Add(x, y.Abs())
		if z.Lt(x) {
			panic(addDetailToError(
				errCalculationError,
				ufmt.Sprintf("Condition failed: (z must be >= x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	}

	return z
}
