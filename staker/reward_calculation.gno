package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

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
			errInvalidTier,
			ufmt.Sprintf("staker.gno__tierRatio() || tier(%d) is not valid", tier),
		))
	}
}

type poolTier struct {
	tier1 *avl.Tree // blockNumber -> uint64 poolCount
	tier2 *avl.Tree // blockNumber -> uint64 poolCount
	tier3 *avl.Tree // blockNumber -> uint64 poolCount

	tierRatio *avl.Tree // blockNumber -> TierRatio

	tierMembership *avl.Tree // poolPath -> blockNumber -> tier(0(deleted), 1, 2, 3)

	// rewardCache is used to calculate internal reward for each tier
	// reward = emission / (number of pools in tier) * (tier's ratio)
	tier1RewardCache *avl.Tree // blockNumber -> *u256.Uint
	lastTier1RewardCacheHeight uint64

	tier2RewardCache *avl.Tree // blockNumber -> *u256.Uint
	lastTier2RewardCacheHeight uint64

	tier3RewardCache *avl.Tree // blockNumber -> *u256.Uint
	lastTier3RewardCacheHeight uint64
}

var (
	poolTier poolTier = poolTier{
		tier1: avl.NewTree(),
		tier2: avl.NewTree(),
		tier3: avl.NewTree(),
		tierRatio: avl.NewTree(),
		tierMembership: avl.NewTree(),
		tier1RewardCache: avl.NewTree(),
		lastTier1RewardCacheHeight: 0,
		tier2RewardCache: avl.NewTree(),
		lastTier2RewardCacheHeight: 0,
		tier3RewardCache: avl.NewTree(),
		lastTier3RewardCacheHeight: 0,
	}
)

func (self *poolTier) lastCount(tier uint64, endHeight uint64) uint64 {
	tree := self.of(tier)
	count := uint64(0)
	tree.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		count = value.(uint64)
		return true
	})
	return count
}

func (self *poolTier) lastRatio(tier uint64, endHeight uint64) uint64 {
	ratio := uint64(0)
	tree := self.of(tier)
	tree.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		ratio = value.(TierRatio).get(tier)
		return true
	})
	return ratio
}

func (self *poolTier) lastTier(poolPath string, endHeight uint64) uint64 {
	tier := uint64(0)
	poolTierMembershipI, ok := self.tierMembership.Get(poolPath)
	if !ok {
		return tier
	}
	poolTierMembership := poolTierMembershipI.(*avl.Tree)
	poolTierMembership.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		tier = value.(uint64)
		return true
	})
	return tier
}

func (self *poolTier) lastReward(tier uint64, endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	tree := self.rewardCacheOf(tier)
	tree.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *poolTier) hasPool(poolPath string) bool {
	if _, ok := self.tierMembership.Get(poolPath); ok {
		return true
	}
	return false
}

func (self *poolTier) countOf(tier uint64) *avl.Tree {
	switch tier {
	case 1:
		return self.tier1
	case 2:
		return self.tier2
	case 3:
		return self.tier3
	default:
		panic(addDetailToError(
			errInvalidTier,
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

func (self *poolTier) tierMembershipUpdates(poolPath string, startHeight, endHeight uint64) ([]uint64, []uint64) {
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	poolTierMembership := self.tierMembership.Get(poolPath)
	poolTierMembership.Iterate(startHeight, endHeight, func(key string, value interface{}) bool {
		height := std.MustParseUint(key, 10)
		heights = append(heights, height)
		updates = append(updates, value.(uint64))
		return false
	})

	return heights, updates
}

func (self *poolTier) tierDenominatorUpdates(tier uint64, startHeight, endHeight uint64) ([]uint64, []uint64) {
	// count * (ratio * 100) updates
	currentCount := self.lastCount(tier, startHeight)
	currentRatio := self.lastRatio(tier, startHeight)
	heights := make([]uint64, 0)
	updates := make([]uint64, 0)

	tierCountTree := self.countOf(tier)
	lastHeight := startHeight
	tierCountTree.Iterate(startHeight, endHeight, func(key string, value interface{}) bool {
		height := std.MustParseUint(key, 10)

		self.tierRatio.Iterate(lastHeight, height, func(key string, value interface{}) bool {
			ratioHeight := std.MustParseUint(key, 10)
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
	self.tierRatio.Iterate(lastHeight, endHeight, func(key string, value interface{}) bool {
		ratioHeight := std.MustParseUint(key, 10)
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

func (self *poolTier) rewardCacheOf(tier uint64) *avl.Tree {
	switch tier {
	case 1:
		return self.tier1RewardCache
	case 2:
		return self.tier2RewardCache
	case 3:
		return self.tier3RewardCache
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("staker.gno__rewardCacheOf() || tier(%d) is not valid", tier),
		))
	}
}

func (self *poolTier) cacheTierReward(tier uint64, endHeight uint64) {
	startHeight := self.lastRewardCacheHeight
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

type pool struct {
	// conceptually equal with Pool.liquidity but only for the staked positions
	// updated each time when the pool crosses a staked tick
	stakedLiquidity *avl.Tree // blockNumber -> *u256.Uint

	// cache of the internal reward for each pool in tier
	rewardCache *avl.Tree // blockNumber -> *u256.Uint
	lastRewardCacheHeight uint64
}

func (self *pool) lastStakedLiquidity(end uint64) *u256.Uint {
	stakedLiquidity := u256.Zero()
	self.totalStakedLiquidityInRange.ReverseIterate(0, end, func(key string, value interface{}) bool {
		stakedLiquidity = value.(*u256.Uint)
		return true
	})
	return stakedLiquidity
}

func (self *pool) lastReward(endHeight uint64) *u256.Uint {
	reward := u256.Zero()
	self.rewardCache.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		reward = value.(*u256.Uint)
		return true
	})
	return reward
}

func (self *pool) stakedLiquidityUpdates(startHeight, endHeight uint64) ([]uint64, []*u256.Uint) {
	heights := make([]uint64, 0)
	updates := make([]*u256.Uint, 0)
	self.stakedLiquidity.Iterate(startHeight, endHeight, func(key string, value interface{}) bool {
		height := std.MustParseUint(key, 10)
		heights = append(heights, height)
		updates = append(updates, value.(*u256.Uint))
		return false
	})
	return heights, updates
}

// startHeight should be pool.lastRewardCacheHeight
func (self *poolTier) cachePoolReward(poolRewardCache *avl.Tree, poolPath string, startHeight, endHeight uint64, currentTier uint64) {
	currentTier := self.lastTier(poolPath, startHeight)
	tier.tierMembership.Iterate(startHeight, endHeight, func(key string, value interface{}) bool {
		membershipUpdateHeight := std.MustParseUint(key, 10)
		if currentTier == 0 {
			// ignore reward updates
			currentTier = value.(uint64)
			return false
		}
		self.rewardCacheOf(currentTier).Iterate(startHeight, membershipUpdateHeight, func(key string, value interface{}) bool {
			height := std.MustParseUint(key, 10)
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
	self.rewardCacheOf(currentTier).Iterate(lastHeight, endHeight, func(key string, value interface{}) bool {
		height := std.MustParseUint(key, 10)
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

func (pool *pool) tickCrossesToEligibleIntervals(
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
		endHeight := std.GetHeight()
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
		}), value
	}

	if heights[0] != startHeight {
		intervals = append(intervals, interval{
			startHeight,
			endHeight: heights[0],
			value,
		})
		startHeight = heights[0]
		value = updates[0]
		heights = heights[1:]
		updates = updates[1:]
	}
	for i := 0; i < len(updates); i++ {
		intervals = append(intervals, interval{
			startHeight,
			endHeight: heights[i],
			value,
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

type tick struct {
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
	cross *avl.Tree
}

func (self *tick) crossInfo(startHeight, endHeight uint64) ([]uint64, []bool) {
	tickCrossHeights := make([]uint64, 0)
	tickCrossZeroForOnes := make([]bool, 0)

	self.cross.Iterate(startHeight, endHeight, func(key string, zeroForOne bool) bool {
		blockNumber := std.MustParseUint(key, 10)
		tickCrossHeights = append(tickCrossHeights, blockNumber)
		tickCrossZeroForOnes = append(tickCrossZeroForOnes, zeroForOne)
		return false
	})

	return tickCrossHeights, tickCrossZeroForOnes
}

func (self *tick) updateCross(blockNumber uint64, zeroForOne bool) {
	cross := self.cross.Get(blockNumber)
	if cross == nil {
		self.cross.Insert(blockNumber, zeroForOne)
	} else if cross != zeroForOne {
		self.cross.Delete(blockNumber)
	}
}

func (self *tick) lastCross(endHeight uint64) bool {
	// There MUST be at least one cross, set when the position is staked
	cross := false	
	self.cross.ReverseIterate(0, endHeight, func(key string, value interface{}) bool {
		cross = value.(bool)
		return true
	})
	return cross
}

type pools struct {
	tree *avl.Tree // string poolPath -> pool
}

func (self *pools) get(poolPath string) pool {
	v, ok := self.tree.Get(poolPath)
	if !ok {
		return pool{
			stakedLiquidity: avl.NewTree(),
			tier:            avl.NewTree(),
			reward:          avl.NewTree(),
		}
	}
	return v.(pool)
}

func (self *pools) set(poolPath string, pool pool) {
	self.tree.Set(poolPath, pool)
}

type ticks struct {
	tree *avl.Tree // int32 tickId -> tick
}

func (self *ticks) get(tickId int32) tick {
	tickIdStr := strconv.Itoa(int(tickId))
	v, ok := self.tree.Get(tickIdStr)
	if !ok {
		return tick{
			stakedLiquidityGross: i256.Zero(),
			stakedLiquidityDelta: i256.Zero(),
			cross:                avl.NewTree(),
		}
	}
	return v.(tick)
}

func (self *ticks) set(tickId int32, tick tick) {
	tickIdStr := strconv.Itoa(int(tickId))
	if tick.stakedLiquidityGross.IsZero() {
		// TODO: check if this could cause memory leak of GC halt
		// because tick.cross being dropped may overload the VM GC
		self.tree.Delete(tickIdStr)
		return
	}
	self.tree.Set(tickIdStr, tick)
}


type positions struct {
	tree *avl.Tree // uint64 positionId -> position
}

func (self *positions) get(positionId uint64) position {
	v, ok := self.tree.Get(positionId)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__positions.get() || positionId(%d) not found", positionId),
		))
	}
	return v.(position)
}

func (self *positions) set(positionId uint64, position position) {
	self.tree.Set(positionId, position)
}

type warmup struct {
	nextWarmupHeight uint64
	warmupRatio uint64
}

type position struct {
	lastCollectHeight uint64 // last collect block height

	warmups []warmup
}

func NewPosition(currentHeight uint64, avgBlockTimeInMs int64) *position {
	msInDay := uint64(86400000)
	blocksInDay := msInDay / uint64(avgBlockTimeInMs)
	blocksIn5Days := uint64(5 * blocksInDay)
	blocksIn10Days := uint64(10 * blocksInDay)
	blocksIn30Days := uint64(30 * blocksInDay)

	return &position{
		lastCollectHeight: currentHeight,
		warmups: []warmup{
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

func (self *position) findWarmup(height uint64) warmup {
	for _, warmup := range self.warmups {
		if height < warmup.nextWarmupHeight {
			return warmup
		}
	}
	return self.warmups[len(self.warmups) - 1]
}

func (self warmup) calculateReward(rewardAcc, penaltyAcc, blockNumber uint64, perBlockReward *u256.Uint) {
	rewardRatio := u256.NewUint(self.warmupRatio)
	penaltyRatio := u256.NewUint(100 - self.warmupRatio)
	totalReward := blockNumber.Mul(blockNumber, perBlockReward)
	rewardAcc.Add(rewardAcc, rewardRatio.Mul(rewardRatio, totalReward))
	penaltyAcc.Add(penaltyAcc, penaltyRatio.Mul(penaltyRatio, totalReward))
}

func (self *position) calculateReward(rewardAcc, penaltyAcc, perBlockReward *u256.Uint, startHeight, endHeight uint64) {
	if startHeight >= endHeight {
		return
	}

	warmup := findWarmup(self.warmups, startHeight)
	if endHeight < warmup.nextWarmupHeight {
		warmup.calculateReward(rewardAcc, penaltyAcc, endHeight - startHeight, perBlockReward)
		return
	}

	warmup.calculateReward(rewardAcc, penaltyAcc, warmup.nextWarmupHeight - startHeight, perBlockReward)
	self.calculateReward(rewardAcc, penaltyAcc, perBlockReward, warmup.nextWarmupHeight, endHeight)
}

func (self *position) eligibleIntervalsToReward(intervals []interval, pool *pool, endHeight uint64) (*u256.Uint, *u256.Uint) {
	startHeight := self.lastCollectHeight
	
	totalReward := u256.Zero()
	totalPenalty := u256.Zero()

	for _, interval := range intervals {
		totalStakedLiquidity := interval.value
		currentReward := pool.lastReward(interval.startHeight)
		currentHeight := interval.startHeight
		pool.rewardCache.Iterate(interval.startHeight, interval.endHeight, func(key string, value interface{}) bool {
			height := std.MustParseUint(key, 10)
		
			self.calculateReward(totalReward, totalPenalty, currentReward, currentHeight, height)

			currentHeight = height
			currentReward = value.(*u256.Uint)
			return false
		})
		self.calculateReward(totalReward, totalPenalty, currentReward, currentHeight, interval.endHeight)
	}	

	u100 := u256.NewUint(100)
	totalReward = totalReward.Div(totalReward, u100)
	totalPenalty = totalPenalty.Div(totalPenalty, u100)

	return totalReward, totalPenalty
}


var (
	pools = pools{
		tree: avl.NewTree(),
	}

	ticks = ticks{
		tree: avl.NewTree(),
	}

	positions = positions{
		tree: avl.NewTree(),
	}
)

func modifyPosition(poolPath string, tokenId uint64, liquidity *u256.Uint) {
	// update staker side pool info
	if pn.PositionIsInRange(tokenId) {
		pool := pools.get(poolPath)
		pool.stakedLiquidity = liquidityMathAddDelta(pool.stakedLiquidity, liquidity)
		pools.set(poolPath, pool)
	}

	// update staker side tick info
	lowerTickId := pn.PositionGetPositionTickLower(tokenId)
	lowerTick := ticks.get(lowerTickId)
	lowerTick.stakedLiquidityGross = liquidityMathAddDelta(lowerTick.stakedLiquidityGross, liquidity)
	lowerTick.stakedLiquidityDelta = liquidityMathAddDelta(lowerTick.stakedLiquidityDelta, liquidity)

	currentTick := pl.PoolGetSlot0Tick(poolPath)
	lowerTick.updateCross(std.GetHeight(), currentTick < lowerTickId)
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

	tick, ok := ticks.get(tickId)
	if !ok {
		return
	}

	pool, ok := pools.get(poolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__tickCrossHook() || poolPath(%s) not found", poolPath),
		))
	}

	blockNumber := std.GetHeight()
	tick.updateCross(blockNumber, zeroForOne)

	liquidityInRangeDelta := tick.liquidityInRangeDelta
	if zeroForOne {
		liquidityInRangeDelta = i256.Zero().Neg(liquidityInRangeDelta)
	}
	stakedLiquidity := pool.stakedLiquidity.Get(blockNumber)
	pool.stakedLiquidity.Set(blockNumber, liquidityMathAddDelta(stakedLiquidity, liquidityInRangeDelta))

	// I'm not sure if this is needed. We may not need to update the pool info because the stakedLiquidity pointer itself has not changed.
	pools.set(poolPath, pool)
}
