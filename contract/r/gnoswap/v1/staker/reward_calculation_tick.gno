package staker

import (
	"strconv"
	"strings"

	"gno.land/p/nt/avl"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	zeroUint256 = u256.Zero()
	zeroInt256  = i256.Zero()
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

	tick, ok := v.(*Tick)
	if !ok {
		panic("failed to cast value to *Tick")
	}
	return tick
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
	acc := u256.Zero()
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
	if self.stakedLiquidityGross.Lt(zeroUint256) {
		panic("stakedLiquidityGross is negative")
	}
	self.stakedLiquidityDelta = i256.Zero().Add(self.stakedLiquidityDelta, liquidity)
}

// modifyDepositUpper updates the tick's liquidity info by treating the deposit as an upper tick
func (self *Tick) modifyDepositUpper(currentTime int64, liquidity *i256.Int) {
	self.stakedLiquidityGross = liquidityMathAddDelta(self.stakedLiquidityGross, liquidity)
	if self.stakedLiquidityGross.Lt(zeroUint256) {
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
// This struct is used to accumulate tick cross events during a single swap transaction
// for batch processing to optimize gas usage and computational efficiency
type SwapTickCross struct {
	tickId     int32     // The tick index that was crossed
	zeroForOne bool      // Direction of the swap (true: token0->token1, false: token1->token0)
	delta      *i256.Int // Pre-calculated liquidity delta for this tick cross
}

// SwapBatchProcessor processes tick crosses in batch for a swap
// This processor accumulates all tick crosses that occur during a single swap
// and processes them together at the end, reducing redundant calculations
// and state updates that would occur with individual tick processing
type SwapBatchProcessor struct {
	poolPath  string          // The pool path identifier for this swap
	pool      *Pool           // Reference to the pool being swapped in
	crosses   []SwapTickCross // Accumulated tick crosses during the swap
	timestamp int64           // Timestamp when the swap started
	isActive  bool            // Flag to prevent accumulation after swap ends
}

// swapStartHook is called when a swap starts
// This hook initializes the batch processor for accumulating tick crosses
func swapStartHook(pools *Pools) func(poolPath string, timestamp int64) {
	return func(poolPath string, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			// Initialize batch processor for this swap
			// This will accumulate all tick crosses until swap completion
			currentSwapBatch = &SwapBatchProcessor{
				poolPath:  poolPath,
				pool:      pool,
				crosses:   make([]SwapTickCross, 0), // Pre-allocate slice for tick crosses
				timestamp: timestamp,
				isActive:  true, // Enable accumulation mode
			}
		}(cross)
	}
}

// swapEndHook is called when a swap ends
// This hook processes all accumulated tick crosses in a single batch operation
// and cleans up the batch processor. The batch processing approach provides:
// 1. O(1) pool state updates instead of O(n) where n = number of tick crosses
// 2. Reduced computational overhead for reward calculations
// 3. Atomic processing ensuring consistency across all tick updates
func swapEndHook(pools *Pools) func(poolPath string) error {
	return func(poolPath string) error {
		return func(cur realm) error {
			// Validate batch processor state
			if currentSwapBatch == nil || !currentSwapBatch.isActive || currentSwapBatch.poolPath != poolPath {
				return nil
			}

			// Disable further accumulation
			currentSwapBatch.isActive = false

			// Process all accumulated tick crosses in a single batch
			// This is where the optimization happens - instead of processing
			// each tick cross individually, we calculate cumulative effects
			err := processBatchedTickCrosses()
			if err != nil {
				return err
			}

			// Clean up batch processor
			currentSwapBatch = nil

			return nil
		}(cross)
	}
}

// tickCrossHook is called when a tick is crossed
// This hook implements intelligent routing between batch processing and immediate processing:
// - During swaps: accumulates tick crosses for batch processing at swap end
// - Outside swaps: processes tick crosses immediately for real-time updates
// The hybrid approach optimizes for both swap performance and non-swap responsiveness
func tickCrossHook(pools *Pools) func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			tick := pool.ticks.Get(tickId)
			// Skip ticks with zero staked liquidity (no reward impact)
			if tick.stakedLiquidityDelta.Sign() == 0 {
				return
			}

			// Batch processing path: accumulate tick crosses during active swap
			if currentSwapBatch != nil && currentSwapBatch.isActive && currentSwapBatch.poolPath == poolPath {
				// Pre-calculate liquidity delta with direction consideration
				// zeroForOne swap: liquidity delta is negated (liquidity being removed from current tick)
				liquidityDelta := tick.stakedLiquidityDelta
				if zeroForOne {
					liquidityDelta = i256.Zero().Neg(liquidityDelta)
				}

				// Accumulate this tick cross for batch processing
				currentSwapBatch.crosses = append(currentSwapBatch.crosses, SwapTickCross{
					tickId:     tickId,
					zeroForOne: zeroForOne,
					delta:      liquidityDelta, // Store pre-calculated delta for efficiency
				})
				return
			}

			// Immediate processing path: handle tick crosses outside of swap context
			// This ensures real-time updates for non-swap operations (e.g., position modifications)
			processTickCrossImmediate(pool, tick, tickId, zeroForOne, timestamp)
		}(cross)
	}
}

// processTickCrossImmediate processes a single tick cross immediately
// This function handles individual tick crosses for non-swap operations
// where batch processing is not applicable (e.g., position modifications, liquidations)
func processTickCrossImmediate(pool *Pool, tick *Tick, tickId int32, zeroForOne bool, timestamp int64) {
	// Calculate the effective tick position after crossing
	// For zeroForOne swaps, liquidity becomes effective one tick lower
	nextTick := tickId
	if zeroForOne {
		nextTick-- // Move to the lower tick where liquidity becomes active
	}

	// Calculate liquidity delta with direction consideration
	liquidityDelta := tick.stakedLiquidityDelta
	if zeroForOne {
		// Negate delta for zeroForOne direction (liquidity being removed from current range)
		liquidityDelta = i256.Zero().Neg(liquidityDelta)
	}

	// Update pool's cumulative deposit with the liquidity change
	newAcc := pool.modifyDeposit(liquidityDelta, timestamp, nextTick)

	// Update the tick's outside accumulation for reward calculations
	// This ensures proper reward distribution tracking across tick boundaries
	tick.updateCurrentOutsideAccumulation(timestamp, newAcc)
}

// processBatchedTickCrosses processes all accumulated tick crosses at once
// This is the core optimization function that processes multiple tick crosses in a single operation.
// Instead of updating pool state for each tick cross individually (O(n) operations),
// it calculates the cumulative effect and applies it once (O(1) pool updates + O(n) tick updates).
func processBatchedTickCrosses() error {
	// Early exit for empty batches
	if currentSwapBatch == nil || len(currentSwapBatch.crosses) == 0 {
		return nil
	}

	// Validate pool reference
	if currentSwapBatch.pool == nil {
		return errPoolNotFound
	}

	batch := currentSwapBatch
	timestamp := batch.timestamp

	// Phase 1: Calculate cumulative liquidity delta across all tick crosses
	// This replaces multiple individual pool updates with a single cumulative update
	cumulativeDelta := i256.Zero()
	for _, tickCross := range batch.crosses {
		newDelta := cumulativeDelta.Add(cumulativeDelta, tickCross.delta)
		cumulativeDelta = newDelta
	}

	// Phase 2: Determine the effective tick position for pool state update
	// Use the last crossed tick as the reference point for cumulative changes
	lastCross := batch.crosses[len(batch.crosses)-1]
	lastTick := lastCross.tickId
	if lastCross.zeroForOne {
		lastTick-- // Adjust for zeroForOne direction
	}

	// Phase 3: Apply cumulative changes to pool state in a single operation
	// This is the key optimization - one pool update instead of many
	newAcc := batch.pool.modifyDeposit(cumulativeDelta, timestamp, lastTick)

	// Phase 4: Update individual tick outside accumulations for reward tracking
	// While we optimize pool updates, each tick still needs its accumulation updated
	// for proper reward distribution calculations
	for _, tickCross := range batch.crosses {
		tick := batch.pool.ticks.Get(tickCross.tickId)
		tick.updateCurrentOutsideAccumulation(timestamp, newAcc)
	}

	return nil
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
