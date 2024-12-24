package staker

import (
	ufmt "gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type Ticks struct {
	tree *UintTree // int32 tickId -> tick
}

var ticks = NewTicks()

func NewTicks() *Ticks {
	return &Ticks{
		tree: NewUintTree(),
	}
}

func (self *Ticks) Get(tickId int32) *Tick {
	v, ok := self.tree.Get(uint64(tickId))
	if !ok {
		tick := &Tick{
			id: tickId,
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

func (self *Tick) currentCross(currentHeight uint64) bool {
	// There MUST be at least one cross, set when the position is staked
	crossI, ok := self.cross.Get(currentHeight)
	if ok {
		return crossI.(bool)
	}
	cross := false
	self.cross.ReverseIterate(0, currentHeight, func(key uint64, value interface{}) bool {
		cross = value.(bool)
		return true
	})
	return cross
}


func (self *Tick) modifyDepositLower(currentHeight uint64, currentTick int32, liquidity *i256.Int) {
	// update staker side tick info
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	self.stakedLiquidityDelta = self.stakedLiquidityDelta.Add(self.stakedLiquidityDelta, liquidity)

	self.updateCross(currentHeight, currentTick < self.id)
	// ticks.Set(self.id, self)
}

func (self *Tick) modifyDepositUpper(currentHeight uint64, currentTick int32, liquidity *i256.Int) {
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	self.stakedLiquidityDelta = self.stakedLiquidityDelta.Sub(self.stakedLiquidityDelta, liquidity)

	self.updateCross(currentHeight, currentTick < self.id)
	// ticks.Set(self.id, self)
}

func TickCrossHook(pools *Pools, ticks *Ticks, height func() int64) func(poolPath string, tickId int32, zeroForOne bool) {
	return func(poolPath string, tickId int32, zeroForOne bool) {
		pool, ok := pools.Get(poolPath)
		if !ok {
			return
		}
	
		tick := ticks.Get(tickId)

		blockNumber := uint64(height())
		tick.updateCross(blockNumber, zeroForOne)
	
		liquidityInRangeDelta := tick.stakedLiquidityDelta
		if zeroForOne {
			liquidityInRangeDelta = i256.Zero().Neg(liquidityInRangeDelta)
		}
		stakedLiquidity := pool.CurrentStakedLiquidity(blockNumber)
		pool.stakedLiquidity.Set(blockNumber, liquidityMathAddDelta(stakedLiquidity, liquidityInRangeDelta))
	
		// I'm not sure if this is needed. We may not need to update the pool info because the stakedLiquidity pointer itself has not changed.
		// pools.Set(poolPath, pool)
	}
}