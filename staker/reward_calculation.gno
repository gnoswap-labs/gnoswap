package staker

import (
	"std"
	"strconv"
	"strings"
	"math"

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
	tier1 uint64
	tier2 uint64
	tier3 uint64
}

func (self *TierRatio) get(tier uint64) uint64 {
	switch tier {
	case 1:
		return self.tier1
	case 2:
		return self.tier2
	case 3:
		return self.tier3
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("staker.gno__tierRatio() || tier(%d) is not valid", tier),
		))
	}
}

type PoolTier struct {
	tier1 *UintTree // blockNumber -> uint64 poolCount
	tier2 *UintTree // blockNumber -> uint64 poolCount
	tier3 *UintTree // blockNumber -> uint64 poolCount

	tierRatio *UintTree // blockNumber -> TierRatio

	tierMembership *avl.Tree // poolPath -> blockNumber -> tier(0(deleted), 1, 2, 3)

	// rewardCache is used to calculate internal reward for each tier
	// reward = emission / (number of pools in tier) * (tier's ratio)
	tier1RewardCache *UintTree // blockNumber -> *u256.Uint
	tier2RewardCache *UintTree // blockNumber -> *u256.Uint
	tier3RewardCache *UintTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight uint64
}

var (
	poolTier *PoolTier = &PoolTier{
		tier1: NewUintTree(),
		tier2: NewUintTree(),
		tier3: NewUintTree(),
		tierRatio: NewUintTree(),
		tierMembership: avl.NewTree(),
		tier1RewardCache: NewUintTree(),
		tier2RewardCache: NewUintTree(),
		tier3RewardCache: NewUintTree(),
		lastRewardCacheHeight: 0,
	}
)

func (self *PoolTier) membershipOf(poolPath string) *UintTree {
	v, ok := self.tierMembership.Get(poolPath)
	if !ok {
		tree := NewUintTree()
		self.tierMembership.Set(poolPath, tree)
		return tree
	}
	return v.(*UintTree)
}

func (self *PoolTier) lastCount(tier uint64, endHeight uint64) uint64 {
	tree := self.countOf(tier)
	count := uint64(0)
	tree.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		count = value.(uint64)
		return true
	})
	return count
}

func (self *PoolTier) lastRatio(tier uint64, endHeight uint64) uint64 {
	ratio := uint64(0)
	self.tierRatio.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		ratio = value.(*TierRatio).get(tier)
		return true
	})
	return ratio
}

func (self *PoolTier) lastTier(poolPath string, endHeight uint64) uint64 {
	tier := uint64(0)
	poolTierMembershipI, ok := self.tierMembership.Get(poolPath)
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

func (self *PoolTier) lastReward(tier uint64, endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	tree := self.rewardCacheOf(tier)
	tree.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *PoolTier) hasPool(poolPath string) bool {
	if _, ok := self.tierMembership.Get(poolPath); ok {
		return true
	}
	return false
}

func (self *PoolTier) countOf(tier uint64) *UintTree {
	switch tier {
	case 1:
		return self.tier1
	case 2:
		return self.tier2
	case 3:
		return self.tier3
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("staker.gno__tier() || tier(%d) is not valid", tier),
		))
	}
}

func calcReward(emission *u256.Uint, denominator uint64) *u256.Uint {
	result := u256.NewUint(100)
	result = result.Mul(result, emission)
	result = result.Div(result, u256.NewUint(denominator))
	return result
}

func (self *PoolTier) tierMembershipUpdates(poolPath string, startHeight, endHeight uint64) ([]uint64, []uint64) {
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

func (self *PoolTier) tierDenominatorUpdates(tier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	// count * (ratio * 100) updates
	currentCount := self.lastCount(tier, startHeight)
	currentRatio := self.lastRatio(tier, startHeight)
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	tierCountTree := self.countOf(tier)
	lastHeight := startHeight
	tierCountTree.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		self.tierRatio.Iterate(lastHeight, height, func(ratioHeight uint64, value interface{}) bool {
			currentRatio = value.(TierRatio).get(tier)
			update := currentCount * currentRatio
			if ratioHeight == lastHeight {
				heights[len(heights) - 1] = ratioHeight
				updates[len(updates) - 1] = update
			} else {
				heights = append(heights, ratioHeight)
				updates = append(updates, update)
			}
			return false
		})

		currentCount = value.(uint64)
		heights = append(heights, height)
		updates = append(updates, currentCount * currentRatio)

		lastHeight = height

		return false
	})

	// take account of ratio changes after the last count change
	self.tierRatio.Iterate(lastHeight, endHeight, func(key uint64, value interface{}) bool {
		ratioHeight := key
		currentRatio = value.(TierRatio).get(tier)
		update := currentCount * currentRatio
		if ratioHeight == lastHeight {
			heights[len(heights) - 1] = ratioHeight
			updates[len(updates) - 1] = update
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
		return self.tier1RewardCache
	case 2:
		return self.tier2RewardCache
	case 3:
		return self.tier3RewardCache
	default:
		panic(addDetailToError(
			errInvalidPoolTier,
			ufmt.Sprintf("staker.gno__rewardCacheOf() || tier(%d) is not valid", tier),
		))
	}
}

func (self *PoolTier) cacheTierReward(tier uint64, endHeight uint64) {
	startHeight := self.lastRewardCacheHeight(tier, endHeight)
	emissionUpdateHeights, emissionUpdates := gns.PerBlockMintUpdates(startHeight, endHeight)
	currentEmissionUpdateHeight, currentEmissionUpdate := gns.LastPerBlockMintUpdate(startHeight)
	rewardCache := self.rewardCacheOf(tier)
	for i := 0; i < len(emissionUpdateHeights); i++ {
		emission := emissionUpdates[i]
		heights, updates := self.tierDenominatorUpdates(tier, currentEmissionUpdateHeight, emissionUpdateHeights[i])
		for j := 0; j < len(heights); j++ {
			reward := calcReward(currentEmissionUpdate, updates[j])
			rewardCache.Set(heights[j], reward)
		}
		currentEmissionUpdateHeight = emissionUpdateHeights[i]
		currentEmissionUpdate = emissionUpdates[i]
	}
}

type Pool struct {
	// conceptually equal with Pool.liquidity but only for the staked positions
	// updated each time when the pool crosses a staked tick
	stakedLiquidity *UintTree // blockNumber -> *u256.Uint

	// cache of the internal reward for each pool in tier
	rewardCache *UintTree // blockNumber -> *u256.Uint
	lastRewardCacheHeight uint64
}

func (self *Pool) lastStakedLiquidity(end uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.stakedLiquidity.ReverseIterate(0, end, func(key uint64, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *Pool) lastReward(endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	self.rewardCache.ReverseIterate(0, endHeight, func(key uint64, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *Pool) stakedLiquidityUpdates(startHeight, endHeight uint64) ([]uint64, []*u256.Uint) {
	heights := make([]uint64, 0)
	updates := make([]*u256.Uint, 0)
	self.stakedLiquidity.Iterate(startHeight, endHeight, func(height uint64, value interface{}) bool {
		heights = append(heights, height)
		updates = append(updates, value.(*u256.Uint))
		return false
	})
	return heights, updates
}

// startHeight should be pool.lastRewardCacheHeight
func (self *PoolTier) cachePoolReward(poolRewardCache *UintTree, poolPath string, startHeight, endHeight uint64) {
	currentTier := self.lastTier(poolPath, startHeight)
	self.membershipOf(poolPath).Iterate(startHeight, endHeight, func(membershipUpdateHeight uint64, value interface{}) bool {
		if currentTier == 0 {
			// ignore reward updates
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
			poolRewardCache.Set(membershipUpdateHeight, self.lastReward(currentTier, membershipUpdateHeight))
		}
		return false
	})

	// take account of tier reward changes after the last tier membership change
	self.rewardCacheOf(currentTier).Iterate(lastHeight, endHeight, func(height uint64, value interface{}) bool {
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

func (pool *Pool) tickCrossesToEligibleIntervals(
	tickUpperCrossHeights []uint64,
	tickUpperCrossZeroForOnes []bool,
	tickLowerCrossHeights []uint64,
	tickLowerCrossZeroForOnes []bool,
	currentlyInRange bool,
	startHeight,
	finalHeight uint64,
) []interval {
	intervals := make([]interval, 0, len(tickUpperCrossHeights) + len(tickLowerCrossHeights))

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
					stakedLiquidity := pool.lastStakedLiquidity(startHeight)
					endHeight := currentUpperTickCrossHeight

					intervals = appendIntervals(intervals, pool.stakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
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
					stakedLiquidity := pool.lastStakedLiquidity(startHeight)
					endHeight := currentLowerTickCrossHeight

					intervals = appendIntervals(intervals, pool.stakedLiquidityUpdates, stakedLiquidity, startHeight, endHeight)
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
		stakedLiquidity := pool.lastStakedLiquidity(startHeight)
		intervals = appendIntervals(intervals, pool.stakedLiquidityUpdates, stakedLiquidity, startHeight, finalHeight)
	}

	return intervals
}

func appendIntervals(intervals []interval, updatesFn func(uint64, uint64) ([]uint64, []*u256.Uint), value *u256.Uint, startHeight, endHeight uint64) ([]interval) {
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
			endHeight: heights[0],
			value: value,
		})
		startHeight = heights[0]
		value = updates[0]
		heights = heights[1:]
		updates = updates[1:]
	}
	for i := 0; i < len(updates); i++ {
		intervals = append(intervals, interval{
			startHeight: startHeight,
			endHeight: heights[i],
			value: value,
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
	stakedLiquidityGross *i256.Int

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

func (self *Pools) get(poolPath string) (*Pool, bool) {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		return nil, false
	}
	return v.(*Pool), true
}

func (self *Pools) set(poolPath string, pool *Pool) {
	self.tree.Set(poolPath, pool)
}

type Ticks struct {
	tree *UintTree // int32 tickId -> tick
}

func (self *Ticks) get(tickId int32) *Tick {
	v, ok := self.tree.Get(uint64(tickId))
	if !ok {
		tick := Tick{
			stakedLiquidityGross: i256.Zero(),
			stakedLiquidityDelta: i256.Zero(),
			cross:                NewUintTree(),
		}
		self.tree.Set(uint64(tickId), tick)
		return tick
	}
	return v.(*Tick)
}

func (self *Ticks) set(tickId int32, tick *Tick) {
	if tick.stakedLiquidityGross.IsZero() {
		// TODO: check if this could cause memory leak of GC halt
		// because tick.cross being dropped may overload the VM GC
		self.tree.Delete(uint64(tickId))
		return
	}
	self.tree.Set(uint64(tickId), tick)
}


type Positions struct {
	tree *UintTree // uint64 positionId -> position
}

func (self *Positions) get(positionId uint64) Position {
	v, ok := self.tree.Get(positionId)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__positions.get() || positionId(%d) not found", positionId),
		))
	}
	return v.(Position)
}

func (self *Positions) set(positionId uint64, position *Position) {
	self.tree.Set(positionId, position)
}

type Warmup struct {
	nextWarmupHeight uint64
	warmupRatio uint64
}

type Position struct {
	lastCollectHeight uint64 // last collect block height

	warmups []Warmup
}

func NewPosition(currentHeight uint64, avgBlockTimeInMs int64) *Position {
	msInDay := uint64(86400000)
	blocksInDay := msInDay / uint64(avgBlockTimeInMs)
	blocksIn5Days := uint64(5 * blocksInDay)
	blocksIn10Days := uint64(10 * blocksInDay)
	blocksIn30Days := uint64(30 * blocksInDay)

	return &Position{
		lastCollectHeight: currentHeight,
		warmups: []Warmup{
			{
				nextWarmupHeight: currentHeight + blocksIn5Days,
				warmupRatio: 30,
			},
			{
				nextWarmupHeight: currentHeight + blocksIn10Days,
				warmupRatio: 50,
			},
			{
				nextWarmupHeight: currentHeight + blocksIn30Days,
				warmupRatio: 70,
			},
			{
				nextWarmupHeight: math.MaxUint64,
				warmupRatio: 100,
			},
		},
	}
}

func (self *Position) findWarmup(height uint64) Warmup {
	for _, warmup := range self.warmups {
		if height < warmup.nextWarmupHeight {
			return warmup
		}
	}
	return self.warmups[len(self.warmups) - 1]
}

func (self Warmup) calculateReward(blockNumber uint64, perBlockReward uint64) (uint64, uint64) {
	rewardRatio := self.warmupRatio
	penaltyRatio := 100 - self.warmupRatio
	totalReward := blockNumber * perBlockReward // TODO: check overflow
	return totalReward * rewardRatio / 100, totalReward * penaltyRatio / 100
}

func (self *Position) calculateReward(perBlockReward uint64, startHeight, endHeight uint64) (uint64, uint64) {
	if startHeight >= endHeight {
		return 0, 0
	}

	warmup := self.findWarmup(startHeight)
	if endHeight < warmup.nextWarmupHeight {
		return warmup.calculateReward(endHeight - startHeight, perBlockReward)
	}

	warmupReward, warmupPenalty := warmup.calculateReward(warmup.nextWarmupHeight - startHeight, perBlockReward)
	reward, penalty := self.calculateReward(perBlockReward, warmup.nextWarmupHeight, endHeight)
	return warmupReward + reward, warmupPenalty + penalty
}

func (self *Position) eligibleIntervalsToReward(intervals []interval, pool *Pool, positionLiquidity *u256.Uint, endHeight uint64) (uint64, uint64) {
	totalReward := uint64(0)
	totalPenalty := uint64(0)

	for _, interval := range intervals {
		poolStakedLiquidity := interval.value
		poolReward := pool.lastReward(interval.startHeight)
		currentHeight := interval.startHeight
		pool.rewardCache.Iterate(interval.startHeight, interval.endHeight, func(height uint64, value interface{}) bool {
			perPositionReward := u256.Zero().Mul(poolReward, positionLiquidity)
			perPositionReward = perPositionReward.Div(perPositionReward, poolStakedLiquidity)
			currentReward, currentPenalty := self.calculateReward(perPositionReward.Uint64(), currentHeight, height)
			
			totalReward += currentReward
			totalPenalty += currentPenalty
			
			currentHeight = height
			poolReward = value.(*u256.Uint)
			return false
		})
		perPositionReward := u256.Zero().Mul(poolReward, positionLiquidity)
		perPositionReward = perPositionReward.Div(perPositionReward, poolStakedLiquidity)
		currentReward, currentPenalty := self.calculateReward(perPositionReward.Uint64(), currentHeight, interval.endHeight)
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

	positions = &Positions{
		tree: NewUintTree(),
	}
)

func modifyPosition(poolPath string, tokenId uint64, liquidity *u256.Uint) {
	// update staker side pool info
	if pn.PositionIsInRange(tokenId) {
		pool, ok := pools.get(poolPath)
		if !ok {
			panic(addDetailToError(
				errDataNotFound,
				ufmt.Sprintf("staker.gno__modifyPosition() || poolPath(%s) not found", poolPath),
			))
		}
		pool.stakedLiquidity = liquidityMathAddDelta(pool.stakedLiquidity, liquidity)
		pools.set(poolPath, pool)
	}

	// update staker side tick info
	lowerTickId := pn.PositionGetPositionTickLower(tokenId)
	lowerTick := ticks.get(lowerTickId)
	lowerTick.stakedLiquidityGross = liquidityMathAddDelta(lowerTick.stakedLiquidityGross, liquidity)
	lowerTick.stakedLiquidityDelta = liquidityMathAddDelta(lowerTick.stakedLiquidityDelta, liquidity)

	currentTick := pl.PoolGetSlot0Tick(poolPath)
	lowerTick.updateCross(uint64(std.GetHeight()), currentTick < lowerTickId)
	ticks.set(lowerTickId, lowerTick)

	upperTickId := pn.PositionGetPositionTickUpper(tokenId)
	upperTick := ticks.get(upperTickId)
	upperTick.stakedLiquidityGross = liquidityMathAddDelta(upperTick.stakedLiquidityGross, liquidity)
	upperTick.stakedLiquidityDelta = liquidityMathAddDelta(upperTick.stakedLiquidityDelta, i256.Zero().Neg(liquidity))

	upperTick.updateCross(std.GetHeight(), currentTick < upperTickId)
	ticks.set(upperTickId, upperTick)
}

func tickCrossHook(poolPath string, tickId int32, zeroForOne bool) {
	initialized := pl.PoolGetTickInitialized(poolPath, tickId)
	if !initialized {
		return
	}

	tick := ticks.get(tickId)

	pool, ok := pools.get(poolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__tickCrossHook() || poolPath(%s) not found", poolPath),
		))
	}

	blockNumber := uint64(std.GetHeight())
	tick.updateCross(blockNumber, zeroForOne)

	liquidityInRangeDelta := tick.stakedLiquidityDelta
	if zeroForOne {
		liquidityInRangeDelta = i256.Zero().Neg(liquidityInRangeDelta)
	}
	stakedLiquidity := pool.stakedLiquidity.Get(blockNumber)
	pool.stakedLiquidity.Set(blockNumber, liquidityMathAddDelta(stakedLiquidity, liquidityInRangeDelta))

	// I'm not sure if this is needed. We may not need to update the pool info because the stakedLiquidity pointer itself has not changed.
	pools.set(poolPath, pool)
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
				errLiquidityCalculation,
				ufmt.Sprintf("Condition failed: (z must be < x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	} else {
		z = new(u256.Uint).Add(x, y.Abs())
		if z.Lt(x) {
			panic(addDetailToError(
				errLiquidityCalculation,
				ufmt.Sprintf("Condition failed: (z must be >= x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	}

	return z
}
