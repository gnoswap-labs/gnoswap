package staker

import (
	"strconv"
	"strings"

	"gno.land/p/demo/avl"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
)

// Global batch processor for current swap
var currentSwapBatch *SwapBatchProcessor

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

func NewTicks() Ticks {
	return Ticks{
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
			outsideAccumulation:  NewUintTree(),
		}
		self.tree.Set(EncodeInt(tickId), tick)
		return tick
	}
	return v.(*Tick)
}

func (self *Ticks) set(tickId int32, tick *Tick) {
	if tick.stakedLiquidityGross.IsZero() {
		self.tree.Remove(EncodeInt(tickId))
		return
	}
	self.tree.Set(EncodeInt(tickId), tick)
}

func (self *Ticks) Has(tickId int32) bool {
	return self.tree.Has(EncodeInt(tickId))
}

// Tick represents the state of a specific tick in a pool.
//
// Fields:
// - id (int32): The ID of the tick.
// - stakedLiquidityGross (*u256.Uint): Total gross staked liquidity at this tick.
// - stakedLiquidityDelta (*i256.Int): Net change in staked liquidity at this tick.
// - outsideAccumulation (*UintTree): RewardRatioAccumulation outside the tick.
type Tick struct {
	id int32

	// conceptually equal with Pool.liquidityGross but only for the staked positions
	stakedLiquidityGross *u256.Uint

	// conceptually equal with Pool.liquidityNet but only for the staked positions
	stakedLiquidityDelta *i256.Int

	// currentOutsideAccumulation is the accumulation of the time / TotalStake outside the tick.
	// It is calculated by subtracting the current tick's currentOutsideAccumulation from the global reward ratio accumulation.
	outsideAccumulation *UintTree // timestamp -> *u256.Uint
}

// CurrentOutsideAccumulation returns the latest outside accumulation for the tick
func (self *Tick) CurrentOutsideAccumulation(timestamp int64) *u256.Uint {
	var acc *u256.Uint
	self.outsideAccumulation.ReverseIterate(0, timestamp, func(key int64, value any) bool {
		acc = value.(*u256.Uint)
		return true
	})
	if acc == nil {
		acc = u256.Zero()
	}
	return acc
}

// modifyDepositLower updates the tick's liquidity info by treating the deposit as a lower tick
func (self *Tick) modifyDepositLower(currentTime int64, liquidity *i256.Int) {
	// update staker side tick info
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	if self.stakedLiquidityGross.Lt(u256.Zero()) {
		panic("stakedLiquidityGross is negative")
	}
	self.stakedLiquidityDelta = i256.Zero().Add(self.stakedLiquidityDelta, liquidity)
}

// modifyDepositUpper updates the tick's liquidity info by treating the deposit as an upper tick
func (self *Tick) modifyDepositUpper(currentTime int64, liquidity *i256.Int) {
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	if self.stakedLiquidityGross.Lt(u256.Zero()) {
		panic("stakedLiquidityGross is negative")
	}
	self.stakedLiquidityDelta = i256.Zero().Sub(self.stakedLiquidityDelta, liquidity)
}

// updateCurrentOutsideAccumulation updates the tick's outside accumulation
// It "flips" the accumulation's inside/outside by subtracting the current outside accumulation from the global accumulation
func (self *Tick) updateCurrentOutsideAccumulation(timestamp int64, acc *u256.Uint) {
	currentOutsideAccumulation := self.CurrentOutsideAccumulation(timestamp)
	newOutsideAccumulation := u256.Zero().Sub(acc, currentOutsideAccumulation)
	self.outsideAccumulation.set(timestamp, newOutsideAccumulation)
}

// SwapTickCross stores information about a tick cross during a swap
type SwapTickCross struct {
	tickId     int32
	zeroForOne bool
	delta      *i256.Int // pre-calculated liquidity delta
}

// SwapBatchProcessor processes tick crosses in batch for a swap
type SwapBatchProcessor struct {
	poolPath  string
	pool      *Pool
	crosses   []SwapTickCross
	timestamp int64
	isActive  bool
}

// swapStartHook is called when a swap starts
func swapStartHook(pools *Pools) func(poolPath string, timestamp int64) {
	return func(poolPath string, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			// Initialize batch processor
			currentSwapBatch = &SwapBatchProcessor{
				poolPath:  poolPath,
				pool:      pool,
				crosses:   make([]SwapTickCross, 0), // Pre-allocate for typical swap
				timestamp: timestamp,
				isActive:  true,
			}
		}(cross)
	}
}

// swapEndHook is called when a swap ends
func swapEndHook(pools *Pools) func(poolPath string) {
	return func(poolPath string) {
		func(cur realm) {
			if currentSwapBatch == nil || !currentSwapBatch.isActive || currentSwapBatch.poolPath != poolPath {
				return
			}

			// Mark as inactive to prevent further accumulation
			currentSwapBatch.isActive = false

			// Process all accumulated tick crosses
			processBatchedTickCrosses()

			// Clean up
			currentSwapBatch = nil
		}(cross)
	}
}


// tickCrossHook is called when a tick is crossed
// Optimized to batch process tick crosses during swaps
func tickCrossHook(pools *Pools) func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			tick := pool.ticks.Get(tickId)
			if tick.stakedLiquidityDelta.Sign() == 0 {
				return
			}

			// If batch processor is active for this pool, accumulate
			if currentSwapBatch != nil && currentSwapBatch.isActive && currentSwapBatch.poolPath == poolPath {
				liquidityDelta := tick.stakedLiquidityDelta
				if zeroForOne {
					liquidityDelta = i256.Zero().Neg(liquidityDelta)
				}

				currentSwapBatch.crosses = append(currentSwapBatch.crosses, SwapTickCross{
					tickId:     tickId,
					zeroForOne: zeroForOne,
					delta:      liquidityDelta,
				})
				return
			}

			// Fallback: process immediately (for non-swap tick crosses)
			processTickCrossImmediate(pool, tick, tickId, zeroForOne, timestamp)
		}(cross)
	}
}

// processTickCrossImmediate processes a single tick cross immediately
func processTickCrossImmediate(pool *Pool, tick *Tick, tickId int32, zeroForOne bool, timestamp int64) {
	nextTick := tickId
	if zeroForOne {
		nextTick--
	}

	liquidityDelta := tick.stakedLiquidityDelta
	if zeroForOne {
		liquidityDelta = i256.Zero().Neg(liquidityDelta)
	}

	newAcc := pool.modifyDeposit(liquidityDelta, timestamp, nextTick)
	tick.updateCurrentOutsideAccumulation(timestamp, newAcc)
}

// processBatchedTickCrosses processes all accumulated tick crosses at once
func processBatchedTickCrosses() {
	if currentSwapBatch == nil || len(currentSwapBatch.crosses) == 0 {
		return
	}

	batch := currentSwapBatch
	pool := batch.pool
	timestamp := batch.timestamp

	// Calculate cumulative liquidity delta
	cumulativeDelta := i256.Zero()
	for _, tickCross := range batch.crosses {
		cumulativeDelta = i256.Zero().Add(cumulativeDelta, tickCross.delta)
	}

	// Get the last tick for historical tick update
	lastCross := batch.crosses[len(batch.crosses)-1]
	lastTick := lastCross.tickId
	if lastCross.zeroForOne {
		lastTick--
	}

	// Update pool state once with cumulative changes
	newAcc := pool.modifyDeposit(cumulativeDelta, timestamp, lastTick)

	// Update outside accumulations for all crossed ticks
	for _, tickCross := range batch.crosses {
		tick := pool.ticks.Get(tickCross.tickId)
		tick.updateCurrentOutsideAccumulation(timestamp, newAcc)
	}
}

func setHooks() {
	// Set tick cross hook for pool contract
	pl.SetTickCrossHook(cross, tickCrossHook(pools))

	// Set swap start/end hooks for batch processing
	pl.SetSwapStartHook(cross, swapStartHook(pools))

	pl.SetSwapEndHook(cross, swapEndHook(pools))
}

func init() {
	setHooks()
}
