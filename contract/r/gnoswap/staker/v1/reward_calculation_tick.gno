package v1

import (
	"strconv"
	"strings"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"
)

var (
	zeroUint256 = u256.Zero()
	zeroInt256  = i256.Zero()
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

type TickResolver struct {
	*sr.Tick
}

// CurrentOutsideAccumulation returns the latest outside accumulation for the tick
func (self *TickResolver) CurrentOutsideAccumulation(timestamp int64) *u256.Uint {
	acc := u256.Zero()
	self.OutsideAccumulation().ReverseIterate(0, timestamp, func(key int64, value any) bool {
		v, ok := value.(*u256.Uint)
		if !ok {
			panic("failed to cast value to *u256.Uint")
		}
		acc = v
		return true
	})
	if acc == nil {
		acc = u256.Zero()
	}
	return acc
}

// modifyDepositLower updates the tick's liquidity info by treating the deposit as a lower tick
func (self *TickResolver) modifyDepositLower(currentTime int64, liquidity *i256.Int) {
	// update staker side tick info
	self.SetStakedLiquidityGross(common.LiquidityMathAddDelta(self.StakedLiquidityGross(), liquidity))
	if self.StakedLiquidityGross().Lt(zeroUint256) {
		panic("stakedLiquidityGross is negative")
	}
	self.SetStakedLiquidityDelta(i256.Zero().Add(self.StakedLiquidityDelta(), liquidity))
}

// modifyDepositUpper updates the tick's liquidity info by treating the deposit as an upper tick
func (self *TickResolver) modifyDepositUpper(currentTime int64, liquidity *i256.Int) {
	self.SetStakedLiquidityGross(common.LiquidityMathAddDelta(self.StakedLiquidityGross(), liquidity))
	if self.StakedLiquidityGross().Lt(zeroUint256) {
		panic("stakedLiquidityGross is negative")
	}
	self.SetStakedLiquidityDelta(i256.Zero().Sub(self.StakedLiquidityDelta(), liquidity))
}

// updateCurrentOutsideAccumulation updates the tick's outside accumulation
// It "flips" the accumulation's inside/outside by subtracting the current outside accumulation from the global accumulation
func (self *TickResolver) updateCurrentOutsideAccumulation(timestamp int64, acc *u256.Uint) {
	currentOutsideAccumulation := self.CurrentOutsideAccumulation(timestamp)
	newOutsideAccumulation := u256.Zero().Sub(acc, currentOutsideAccumulation)
	self.OutsideAccumulation().Set(timestamp, newOutsideAccumulation)
}

func NewTickResolver(tick *sr.Tick) *TickResolver {
	return &TickResolver{
		Tick: tick,
	}
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
	pool      *sr.Pool        // Reference to the pool being swapped in
	crosses   []SwapTickCross // Accumulated tick crosses during the swap
	timestamp int64           // Timestamp when the swap started
	isActive  bool            // Flag to prevent accumulation after swap ends
}

// swapStartHook is called when a swap starts
// This hook initializes the batch processor for accumulating tick crosses
func (s *stakerV1) swapStartHook(pools *Pools) func(poolPath string, timestamp int64) {
	return func(poolPath string, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			// Initialize batch processor for this swap
			// This will accumulate all tick crosses until swap completion
			s.currentSwapBatch = &SwapBatchProcessor{
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
func (s *stakerV1) swapEndHook(pools *Pools) func(poolPath string) error {
	return func(poolPath string) error {
		return func(cur realm) error {
			// Validate batch processor state
			if s.currentSwapBatch == nil || !s.currentSwapBatch.isActive || s.currentSwapBatch.poolPath != poolPath {
				return nil
			}

			// Disable further accumulation
			s.currentSwapBatch.isActive = false

			// Process all accumulated tick crosses in a single batch
			// This is where the optimization happens - instead of processing
			// each tick cross individually, we calculate cumulative effects
			err := s.processBatchedTickCrosses()
			if err != nil {
				return err
			}

			// Clean up batch processor
			s.currentSwapBatch = nil

			return nil
		}(cross)
	}
}

// tickCrossHook is called when a tick is crossed
// This hook implements intelligent routing between batch processing and immediate processing:
// - During swaps: accumulates tick crosses for batch processing at swap end
// - Outside swaps: processes tick crosses immediately for real-time updates
// The hybrid approach optimizes for both swap performance and non-swap responsiveness
func (s *stakerV1) tickCrossHook(pools *Pools) func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return func(poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		func(cur realm) {
			pool, ok := pools.Get(poolPath)
			if !ok {
				return
			}

			tick := pool.Ticks().Get(tickId)
			// Skip ticks with zero staked liquidity (no reward impact)
			if tick.StakedLiquidityDelta().Sign() == 0 {
				return
			}

			// Batch processing path: accumulate tick crosses during active swap
			if s.currentSwapBatch != nil && s.currentSwapBatch.isActive && s.currentSwapBatch.poolPath == poolPath {
				// Pre-calculate liquidity delta with direction consideration
				// zeroForOne swap: liquidity delta is negated (liquidity being removed from current tick)
				liquidityDelta := tick.StakedLiquidityDelta()
				if zeroForOne {
					liquidityDelta = i256.Zero().Neg(liquidityDelta)
				}

				// Accumulate this tick cross for batch processing
				s.currentSwapBatch.crosses = append(s.currentSwapBatch.crosses, SwapTickCross{
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
func processTickCrossImmediate(pool *sr.Pool, tick *sr.Tick, tickId int32, zeroForOne bool, timestamp int64) {
	// Calculate the effective tick position after crossing
	// For zeroForOne swaps, liquidity becomes effective one tick lower
	nextTick := tickId
	if zeroForOne {
		nextTick-- // Move to the lower tick where liquidity becomes active
	}

	// Calculate liquidity delta with direction consideration
	liquidityDelta := tick.StakedLiquidityDelta()
	if zeroForOne {
		// Negate delta for zeroForOne direction (liquidity being removed from current range)
		liquidityDelta = i256.Zero().Neg(liquidityDelta)
	}

	// Update pool's cumulative deposit with the liquidity change
	poolResolver := NewPoolResolver(pool)
	newAcc := poolResolver.modifyDeposit(liquidityDelta, timestamp, nextTick)

	// Update the tick's outside accumulation for reward calculations
	// This ensures proper reward distribution tracking across tick boundaries
	tickResolver := NewTickResolver(tick)
	tickResolver.updateCurrentOutsideAccumulation(timestamp, newAcc)
}

// processBatchedTickCrosses processes all accumulated tick crosses at once
// This is the core optimization function that processes multiple tick crosses in a single operation.
// Instead of updating pool state for each tick cross individually (O(n) operations),
// it calculates the cumulative effect and applies it once (O(1) pool updates + O(n) tick updates).
func (s *stakerV1) processBatchedTickCrosses() error {
	// Early exit for empty batches
	if s.currentSwapBatch == nil || len(s.currentSwapBatch.crosses) == 0 {
		return nil
	}

	// Validate pool reference
	if s.currentSwapBatch.pool == nil {
		return errPoolNotFound
	}

	batch := s.currentSwapBatch
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
	poolResolver := NewPoolResolver(batch.pool)
	newAcc := poolResolver.modifyDeposit(cumulativeDelta, timestamp, lastTick)

	// Phase 4: Update individual tick outside accumulations for reward tracking
	// While we optimize pool updates, each tick still needs its accumulation updated
	// for proper reward distribution calculations
	for _, tickCross := range batch.crosses {
		tick := batch.pool.Ticks().Get(tickCross.tickId)
		tickResolver := NewTickResolver(tick)
		tickResolver.updateCurrentOutsideAccumulation(timestamp, newAcc)
	}

	return nil
}

func (s *stakerV1) setupSwapHooks() {
	pools := s.getPools()

	// Set tick cross hook for pool contract
	pl.SetTickCrossHook(cross, s.tickCrossHook(pools))

	// Set swap start/end hooks for batch processing
	pl.SetSwapStartHook(cross, s.swapStartHook(pools))
	pl.SetSwapEndHook(cross, s.swapEndHook(pools))
}
