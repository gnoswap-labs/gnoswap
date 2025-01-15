package staker

import (
	"std"

	"strconv"
	"strings"

	"gno.land/p/demo/avl"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
)

// EncodeInt takes an int32 and returns a zero-padded decimal string
// with up to 10 digits for the absolute value.
// If the number is negative, the '-' sign comes first, followed by zeros, then digits.
func EncodeInt(num int32) string {
	// Convert the absolute value to a decimal string.
	absValue := int64(num)
	isNegative := false
	if num < 0 {
		isNegative = true
		absValue = -absValue // Safely negate into int64 to avoid overflow.
	}

	s := strconv.FormatInt(absValue, 10)

	// Zero-pad to a total of 10 digits for the absolute value.
	// (The '-' sign will be added later if needed.)
	zerosNeeded := 10 - len(s)
	if zerosNeeded < 0 {
		zerosNeeded = 0
	}

	padded := strings.Repeat("0", zerosNeeded) + s

	// If the original number was negative, prepend '-'.
	if isNegative {
		return "-" + padded
	}
	return padded
}

// Tick mapping for each pool
type Ticks struct {
	tree *avl.Tree // int32 tickId -> tick
}

func NewTicks() *Ticks {
	return &Ticks{
		tree: avl.NewTree(),
	}
}

func (self *Ticks) Get(tickId int32) *Tick {
	v, ok := self.tree.Get(EncodeInt(tickId))
	if !ok {
		tick := &Tick{
			id:                   tickId,
			stakedLiquidityGross: u256.Zero(),
			stakedLiquidityDelta: i256.Zero(),
			//cross:                NewUintTree(),
			outsideAccumulation:  NewUintTree(),
		}
		self.tree.Set(EncodeInt(tickId), tick)
		return tick
	}
	return v.(*Tick)
}

func (self *Ticks) Set(tickId int32, tick *Tick) {
	if tick.stakedLiquidityGross.IsZero() {
		// TODO: check if this could cause memory leak of GC halt
		// because tick.cross being dropped may overload the VM GC
		self.tree.Remove(EncodeInt(tickId))
		return
	}
	self.tree.Set(EncodeInt(tickId), tick)
}

func (self *Ticks) Has(tickId int32) bool {
	return self.tree.Has(EncodeInt(tickId))
}

type TickCross struct {
	cross bool

	// BlockNumber / TotalStake accumulation, Q128.
	// Pool.globalRewardRatioAccumulation at the point of the tick crossing
	accumulation *u256.Uint 
}

// Tick represents the state of a specific tick in a pool.
//
// Fields:
// - id (int32): The ID of the tick.
// - stakedLiquidityGross (*u256.Uint): Total gross staked liquidity at this tick.
// - stakedLiquidityDelta (*i256.Int): Net change in staked liquidity at this tick.
// - cross (*UintTree): Tracks tick crossing events (block number -> zeroForOne).
type Tick struct {
	id int32

	// conceptually equal with Pool.liquidityGross but only for the staked positions
	stakedLiquidityGross *u256.Uint

	// conceptually equal with Pool.liquidityNet but only for the staked positions
	stakedLiquidityDelta *i256.Int

	// currentOutsideAccumulation is the accumulation of the blockNumber / TotalStkae outside the tick.
	// It is calculated by subtracting the current tick's currentOutsideAccumulation from the global reward ratio accumulation.
	outsideAccumulation *UintTree // blockNumber -> *u256.Uint
}

func (self *Tick) CurrentOutsideAccumulation(blockNumber uint64) *u256.Uint {
	var acc *u256.Uint
	self.outsideAccumulation.ReverseIterate(0, blockNumber, func(key uint64, value interface{}) bool {
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		acc = u256.Zero()
	}
	return acc
}
/*
// TickCrosses are encoded as int64, where negative value is backward cross(zeroForOne=true), positive value is forward cross(zeroForOne=false).
func (self *Tick) crossInfo(startHeight, endHeight uint64) []int64 {
	tickCrosses := make([]int64, 0)

	self.cross.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		println("key : ", key, ", value : ", value.(bool))
		zeroForOne := value.(bool)
		if zeroForOne {
			tickCrosses = append(tickCrosses, -int64(key))
		} else {
			tickCrosses = append(tickCrosses, int64(key))
		}
		return false
	})

	return tickCrosses
}

func (self *Tick) updateCross(blockNumber uint64, zeroForOne bool) {
	self.cross.Set(blockNumber, zeroForOne)
	println("updateCross ", self.id, " : ", blockNumber, ", ", zeroForOne)
}

func (self *Tick) previousCross(currentHeight uint64) bool {
	// There MUST be at least one cross, set when the position is staked
	cross := false
	self.cross.ReverseIterate(0, currentHeight-1, func(key uint64, value interface{}) bool {
		println(">>>>>>>>>>>>>>>>> previousCross ", key, value.(bool))
		cross = value.(bool)
		return true
	})
	return cross
}
*/
func (self *Tick) modifyDepositLower(currentHeight uint64, currentTick int32, liquidity *i256.Int) {
	// update staker side tick info
	println("stakedLiquidityGross ", self.stakedLiquidityGross.ToString(), ", liquidity ", liquidity.ToString())
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	if self.stakedLiquidityGross.Lt(u256.Zero()) {
		panic("stakedLiquidityGross is negative")
	}
	self.stakedLiquidityDelta = i256.Zero().Add(self.stakedLiquidityDelta, liquidity)

	println("modifyDepositLower: currentTick =", currentTick, "tickId =", self.id, "stakedLiquidityGross =", self.stakedLiquidityGross.ToString(), "stakedLiquidityDelta =", self.stakedLiquidityDelta.ToString())
	//self.updateCross(currentHeight, currentTick < self.id)
	// ticks.Set(self.id, self)
}

func (self *Tick) modifyDepositUpper(currentHeight uint64, currentTick int32, liquidity *i256.Int) {
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	if self.stakedLiquidityGross.Lt(u256.Zero()) {
		panic("stakedLiquidityGross is negative")
	}
	self.stakedLiquidityDelta = i256.Zero().Sub(self.stakedLiquidityDelta, liquidity)

	println("modifyDepositUpper: currentTick =", currentTick, "tickId =", self.id, "stakedLiquidityGross =", self.stakedLiquidityGross.ToString(), "stakedLiquidityDelta =", self.stakedLiquidityDelta.ToString())
	//self.updateCross(currentHeight, currentTick < self.id)
	// ticks.Set(self.id, self)
}

type PerIntervalFunc = func(startHeight, endHeight uint64)

// Gas optimization: encoding { height: int64, inRange: bool } as int64.
// height will be negative if inRange is false.
func ForEachEligibleInterval(startHeight, endHeight int64, currentInRange bool, tickUpperCross []int64, tickLowerCross []int64, f PerIntervalFunc) (bool, []int64, []int64) {
	tickUpperCrossI := 0
	tickLowerCrossI := 0
	tickUpperCrossLen := len(tickUpperCross)
	tickLowerCrossLen := len(tickLowerCross)

	for tickUpperCrossI < tickUpperCrossLen && tickLowerCrossI < tickLowerCrossLen {
		upperCross := tickUpperCross[tickUpperCrossI]
		lowerCross := tickLowerCross[tickLowerCrossI]

		lowerHeight := lowerCross
		if lowerHeight < 0 {
			lowerHeight = -lowerHeight
		}

		upperHeight := upperCross
		if upperHeight < 0 {
			upperHeight = -upperHeight
		}

		// reached the end height
		if lowerHeight >= endHeight || upperHeight >= endHeight {
			break
		}

		// If the heights are the same, and they have the same zeroForOne, the tick has passed through the whole position range(outrange)
		if upperCross == lowerCross {
			if currentInRange {
				// exit range
				f(uint64(startHeight), uint64(lowerHeight))
				currentInRange = false
			}
			tickUpperCrossI++
			tickLowerCrossI++
			continue
		}

		// If the height is the same, and zeroForOne is different, the tick has entered the position and then "bounced" back(inrange)
		if upperCross == -lowerCross {
			if !currentInRange {
				// enter range
				startHeight = lowerHeight
				currentInRange = true
			}
			tickUpperCrossI++
			tickLowerCrossI++
			continue
		}

		// Upper tick passed,
		// - if zeroForOne, backward cross, negative height, inrange
		// - If !zeroForOne, forward cross, positive height, outrange
		// => inRange == upperCross < 0
		if upperHeight < lowerHeight {
			if upperCross < 0 {
				// enter range
				if !currentInRange {
					startHeight = upperHeight
					currentInRange = true
				}
			} else {
				// exit range
				if currentInRange {
					f(uint64(startHeight), uint64(upperHeight))
					currentInRange = false
				}
			}
			tickUpperCrossI++
			continue
		}

		// Lower tick passed,
		// - if zeroForOne, backward cross, negative height, outrange
		// - If !zeroForOne, forward cross, positive height, inrange
		// => inRange == lowerCross > 0
		if lowerHeight < upperHeight {
			if lowerCross > 0 {
				// enter range
				if !currentInRange {
					startHeight = lowerHeight
					currentInRange = true
				}
			} else {
				// exit range
				if currentInRange {
					f(uint64(startHeight), uint64(lowerHeight))
					currentInRange = false
				}
			}
			tickLowerCrossI++
			continue
		}

		panic("unreachable")
	}

	for ; tickUpperCrossI < len(tickUpperCross); tickUpperCrossI++ {
		cross := tickUpperCross[tickUpperCrossI]
		// reached the end height
		if cross >= endHeight || -cross >= endHeight {
			break
		}
		if cross < 0 {
			// enter range
			if !currentInRange {
				startHeight = -cross
				currentInRange = true
			}
		} else {
			// exit range
			if currentInRange {
				f(uint64(startHeight), uint64(cross))
				currentInRange = false
			}
		}
	}

	for ; tickLowerCrossI < len(tickLowerCross); tickLowerCrossI++ {
		cross := tickLowerCross[tickLowerCrossI]
		// reached the end height
		if cross >= endHeight || -cross >= endHeight {
			break
		}
		if cross > 0 {
			// enter range
			if !currentInRange {
				startHeight = cross
				currentInRange = true
			}
		} else {
			// exit range
			if currentInRange {
				f(uint64(startHeight), uint64(-cross))
				currentInRange = false
			}
		}
	}

	if currentInRange {
		f(uint64(startHeight), uint64(endHeight))
	}

	return currentInRange, tickUpperCross[tickUpperCrossI:], tickLowerCross[tickLowerCrossI:]
}

func (self *Tick) updateCurrentOutsideAccumulation(blockNumber uint64, acc *u256.Uint) {
	currentOutsideAccumulation := self.CurrentOutsideAccumulation(blockNumber)
	println("currentOutsideAccumulation : ", currentOutsideAccumulation.ToString())
	println("accumulation : ", acc.ToString())
	newOutsideAccumulation := u256.Zero().Sub(acc, currentOutsideAccumulation)
	println("newOutsideAccumulation : ", newOutsideAccumulation.ToString())
	self.outsideAccumulation.Set(blockNumber, newOutsideAccumulation)
}

func TickCrossHook(pools *Pools, height func() int64) func(poolPath string, tickId int32, zeroForOne bool) {
	return func(poolPath string, tickId int32, zeroForOne bool) {
		pool, ok := pools.Get(poolPath)
		if !ok {
			return
		}

		println("[[TickCrossHook]]  tickId : ", tickId, ", zeroForOne : ", zeroForOne)
		tick := pool.ticks.Get(tickId)

		blockNumber := uint64(height())
		println("	blockNumber : ", blockNumber)
		//tick.updateCross(blockNumber, zeroForOne)

		println("tickId : ", tickId)

		// historical tick does NOT actually reflect the tick at the blockNumber, but it provides correct ordering for the staked positions.
		// (because TickCrossHook is called only for the staked-initialized ticks)
		// you should not use the historical tick for equality, only for comparison.
		if zeroForOne {
			pool.historicalTick.Set(blockNumber, tickId-1)
		} else {
			pool.historicalTick.Set(blockNumber, tickId)
		}

		liquidityInRangeDelta := tick.stakedLiquidityDelta
		if liquidityInRangeDelta.Sign() == 0 {
			return
		}

		if zeroForOne {
			liquidityInRangeDelta = i256.Zero().Neg(liquidityInRangeDelta)
		}
		stakedLiquidity := pool.CurrentStakedLiquidity(blockNumber)
		println("stakedLiquidity : ", stakedLiquidity.ToString())
		deltaApplied := liquidityMathAddDelta(stakedLiquidity, liquidityInRangeDelta)
		println("deltaApplied : ", deltaApplied.ToString())

		newAcc := pool.updateGlobalRewardRatioAccumulation(blockNumber, stakedLiquidity)
		tick.updateCurrentOutsideAccumulation(blockNumber, newAcc)

		switch deltaApplied.Sign() {
		case -1:
			panic("stakedLiquidity is less than 0")
		case 0:
			if stakedLiquidity.Sign() == 1 {
				// StakedLiquidity moved from positive to zero, start unclaimable period
				pool.startInternalUnclaimablePeriod(blockNumber)
			}
		case 1:
			if stakedLiquidity.Sign() == 0 {
				// StakedLiquidity moved from zero to positive, end unclaimable period
				pool.endInternalUnclaimablePeriod(blockNumber)
			}
		}

		pool.updateRewardByLiquidityChange(*pool.tierRewardTotal, blockNumber, deltaApplied)

		pool.stakedLiquidity.Set(blockNumber, deltaApplied)

		// I'm not sure if this is needed. We may not need to update the pool info because the stakedLiquidity pointer itself has not changed.
		// pools.Set(poolPath, pool)
	}
}

func init() {
	pl.SetTickCrossHook(TickCrossHook(pools, std.GetHeight))
}
