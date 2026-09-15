package pool

import (
	"chain"
	"errors"
	"strconv"
	"time"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	"gno.land/p/gnoswap/consts"
	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"

	pl "gno.land/r/gnoswap/pool"
)

// Hook functions allow external contracts to be notified of swap events.
var (
	// MUST BE IMMUTABLE.
	// DO NOT USE THIS VALUE IN ANY ARITHMETIC OPERATIONS' INITIALIZATION
	zero           = u256.Zero()
	zeroI256       = i256.Zero() /* readonly */
	fixedPointQ128 = u256.MustFromDecimal(Q128)

	maxInt256 = u256.MustFromDecimal(MAX_INT256)
	maxInt64  = i256.Zero().SetInt64(INT64_MAX)
	minInt64  = i256.Zero().SetInt64(INT64_MIN)
)

// SetTickCrossHook sets the hook function called when a tick is crossed during swaps.
//
// Allows staker to monitor liquidity changes at price levels.
// Used for reward calculation when positions enter/exit range.
//
// Only callable by staker contract.
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context validated as current before the hook is
//     stored.
//   - hook: Callback invoked after an initialized tick is crossed with the
//     current pool realm, pool path, tick index, swap direction, and timestamp.
func (i *poolV1) SetTickCrossHook(_ int, rlm realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()

	caller := rlm.Previous().Address()
	access.AssertIsStaker(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	err := i.store.SetTickCrossHook(0, rlm, hook)
	if err != nil {
		panic(err)
	}
}

// SetSwapStartHook sets the hook function called at the beginning of a swap.
//
// Enables pre-swap state tracking for reward distribution.
// Captures timestamp for time-weighted calculations.
//
// Only callable by staker contract.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context validated as current before the hook is
//     stored.
//   - hook: Callback invoked before swap computation with the current pool
//     realm, pool path, and block timestamp.
func (i *poolV1) SetSwapStartHook(_ int, rlm realm, hook func(cur realm, poolPath string, timestamp int64)) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()

	caller := rlm.Previous().Address()
	access.AssertIsStaker(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	err := i.store.SetSwapStartHook(0, rlm, hook)
	if err != nil {
		panic(err)
	}
}

// SetSwapEndHook sets the hook function called at the end of a swap.
//
// Finalizes reward calculations after swap completion.
// Allows error propagation to revert invalid swaps.
//
// Only callable by staker contract.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context validated as current before the hook is
//     stored.
//   - hook: Callback invoked after swap settlement with the current pool realm
//     and pool path; a non-nil error aborts the surrounding swap.
func (i *poolV1) SetSwapEndHook(_ int, rlm realm, hook func(cur realm, poolPath string) error) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()

	caller := rlm.Previous().Address()
	access.AssertIsStaker(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	err := i.store.SetSwapEndHook(0, rlm, hook)
	if err != nil {
		panic(err)
	}
}

// SwapResult encapsulates all state changes from a swap.
// It ensures atomic state transitions that can be applied at once.
type SwapResult struct {
	Amount0              *i256.Int
	Amount1              *i256.Int
	NewSqrtPrice         *u256.Uint
	NewTick              int32
	NewLiquidity         *u256.Uint
	NewProtocolFeeToken0 int64
	NewProtocolFeeToken1 int64
	FeeGrowthGlobal0X128 *u256.Uint
	FeeGrowthGlobal1X128 *u256.Uint
}

// SwapComputation encapsulates the pure computation logic for swaps.
type SwapComputation struct {
	AmountSpecified   *i256.Int
	SqrtPriceLimitX96 *u256.Uint
	ZeroForOne        bool
	ExactInput        bool
	InitialState      SwapState
	Cache             *SwapCache
}

// Swap executes a swap with callback pattern for optimistic transfers.
// This allows flash swaps where tokens are sent before payment is received.
//
// The flow is:
// 1. Pool sends output tokens to recipient
// 2. Pool calls callback on msg.sender
// 3. Callback must ensure pool receives input tokens
// 4. Pool validates its balance increased correctly
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Current propagated realm context; it is validated as current and
//     used for token transfers and callbacks.
//   - token0Path: Registered path of token0; it must be the first token in the
//     pool's canonical token ordering.
//   - token1Path: Registered path of token1; it must be the second token in
//     the pool's canonical token ordering.
//   - fee: Fee tier identifying the registered pool to swap against.
//   - recipient: Address that receives the output token transfer.
//   - zeroForOne: Swap direction; true sells token0 for token1, false sells
//     token1 for token0.
//   - amountSpecified: Signed decimal amount; positive values request exact
//     input, negative values request exact output, and zero is invalid.
//   - sqrtPriceLimitX96: Decimal Q96 square-root-price limit that bounds the
//     swap in its direction; an invalid bound causes the call to panic.
//   - swapCallback: Callback that must settle the input delta after output is
//     sent; it receives signed int64 token deltas and a callback marker, and a
//     non-nil error aborts the swap.
//
// Returns:
//   - string: Signed decimal token0 delta from the pool's perspective; a
//     positive value is owed to the pool and a negative value is sent out.
//   - string: Signed decimal token1 delta from the pool's perspective; a
//     positive value is owed to the pool and a negative value is sent out.
func (i *poolV1) Swap(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	assertIsNotUserCall(0, rlm)
	assertIsValidTokenOrder(token0Path, token1Path)

	amounts := i256.MustFromDecimal(amountSpecified)
	if amounts.IsZero() {
		panic(newErrorWithDetail(
			errInvalidSwapAmount,
			"amountSpecified == 0",
		))
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	observations := i.mustGetObservations(pool.PoolPath())

	slot0Start := pool.Slot0()
	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	blockTimestamp := time.Now().Unix()

	// Call swap start hook if set
	if i.store.HasSwapStartHook() {
		swapStartHook := i.store.GetSwapStartHook()

		if swapStartHook != nil {
			swapStartHook(cross(rlm), pool.PoolPath(), blockTimestamp)
		}
	}

	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.Liquidity().Clone(), blockTimestamp, slot0Start)
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart.Clone(), slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(zeroI256),
		InitialState:      state,
		Cache:             cache,
	}

	var hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
	if i.store.HasTickCrossHook() {
		hook = i.store.GetTickCrossHook()
	}
	onTickCross := func(pool *pl.Pool, tickId int32, zeroForOne bool, timestamp int64) {
		chain.Emit(
			"PoolTickCross",
			"poolPath", pool.PoolPath(),
			"tick", NewTickEventInfo(tickId, *mustGetTick(pool, tickId)).ToString(),
		)
		if hook != nil {
			hook(cross(rlm), pool.PoolPath(), tickId, zeroForOne, timestamp)
		}
	}

	result, err := i.computeSwap(pool, observations, comp, onTickCross)
	if err != nil {
		panic(err)
	}

	// Update oracle BEFORE applying swap result (using pre-swap state)
	if result.NewTick != slot0Start.Tick() {
		observationIndex, observationCardinality, err := writeObservation(
			observations,
			slot0Start.ObservationIndex(),
			cache.blockTimestamp,
			slot0Start.Tick(),
			cache.liquidityStart,
			slot0Start.ObservationCardinality(),
			slot0Start.ObservationCardinalityNext(),
		)
		if err != nil {
			panic(err)
		}
		slot0 := pool.Slot0()
		slot0.SetObservationIndex(observationIndex)
		slot0.SetObservationCardinality(observationCardinality)
		pool.SetSlot0(slot0)
	}

	applySwapResult(pool, result)

	if i.store.HasSwapEndHook() {
		swapEndHook := i.store.GetSwapEndHook()
		if swapEndHook != nil {
			err := swapEndHook(cross(rlm), pool.PoolPath())
			if err != nil {
				panic(err)
			}
		}
	}

	// transfer swap result to recipient then receive input tokens from swap callback
	if zeroForOne {
		// receive token0 from swap callback
		// send token1 to recipient (output)
		if result.Amount1.IsNeg() {
			i.safeTransfer(0, rlm, pool, recipient, token1Path, result.Amount1.Abs(), false)
		}
		i.safeSwapCallback(0, rlm, pool, token0Path, result.Amount0, result.Amount1, zeroForOne, swapCallback)
	} else {
		// receive token1 from swap callback
		// send token0 to recipient (output)
		if result.Amount0.IsNeg() {
			i.safeTransfer(0, rlm, pool, recipient, token0Path, result.Amount0.Abs(), true)
		}
		i.safeSwapCallback(0, rlm, pool, token1Path, result.Amount1, result.Amount0, zeroForOne, swapCallback)
	}

	slot0 := pool.Slot0()
	lastObservation, err := observationAt(observations, slot0.ObservationIndex())
	if err != nil {
		panic(err)
	}

	token0Amount := result.Amount0.ToString()
	token1Amount := result.Amount1.ToString()

	previousRealm := rlm.Previous()

	chain.Emit(
		"Swap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", pool.PoolPath(),
		"zeroForOne", utils.FormatBool(zeroForOne),
		"requestAmount", amountSpecified,
		"sqrtPriceLimitX96", sqrtPriceLimitX96,
		"recipient", recipient.String(),
		"token0Amount", token0Amount,
		"token1Amount", token1Amount,
		"protocolFee0", utils.FormatInt(pool.ProtocolFeesToken0()),
		"protocolFee1", utils.FormatInt(pool.ProtocolFeesToken1()),
		"sqrtPriceX96", pool.Slot0SqrtPriceX96().ToString(),
		"exactIn", strconv.FormatBool(comp.ExactInput),
		"currentTick", strconv.FormatInt(int64(pool.Slot0Tick()), 10),
		"liquidity", pool.Liquidity().ToString(),
		"feeGrowthGlobal0X128", pool.FeeGrowthGlobal0X128().ToString(),
		"feeGrowthGlobal1X128", pool.FeeGrowthGlobal1X128().ToString(),
		"balanceToken0", utils.FormatInt(pool.BalanceToken0()),
		"balanceToken1", utils.FormatInt(pool.BalanceToken1()),
		"tickCumulative", utils.FormatInt(lastObservation.TickCumulative()),
		"secondsPerLiquidityCumulativeX128", lastObservation.SecondsPerLiquidityCumulativeX128(),
		"observationTimestamp", utils.FormatInt(lastObservation.BlockTimestamp()),
	)

	return token0Amount, token1Amount
}

// DrySwap simulates a swap against an isolated pool and observation snapshot;
// it never writes stored pool or oracle state.
//
// Parameters:
//   - token0Path: Registered path of token0; it must be the first token in the
//     pool's canonical token ordering.
//   - token1Path: Registered path of token1; it must be the second token in
//     the pool's canonical token ordering.
//   - fee: Fee tier identifying the registered pool to simulate.
//   - zeroForOne: Swap direction; true sells token0 for token1, false sells
//     token1 for token0.
//   - amountSpecified: Signed decimal amount; positive values request exact
//     input, negative values request exact output, and zero is invalid.
//   - sqrtPriceLimitX96: Decimal Q96 square-root-price limit that bounds the
//     simulation in its direction.
//
// Returns:
//   - amount0: Signed decimal token0 delta from the pool's perspective, or
//     "0" when simulation fails.
//   - amount1: Signed decimal token1 delta from the pool's perspective, or
//     "0" when simulation fails.
//   - err: Nil when the simulation succeeds; non-nil for invalid inputs,
//     missing pool state, invalid limits, computation failures, or insufficient
//     pool output balance.
func (i *poolV1) DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (amount0, amount1 string, err error) {
	defer func() {
		if r := recover(); r != nil {
			amount0 = "0"
			amount1 = "0"
			if recoveredErr, ok := r.(error); ok {
				err = recoveredErr
			} else {
				err = ufmt.Errorf("%v", r)
			}
		}
	}()

	amounts := i256.MustFromDecimal(amountSpecified)
	if amounts.IsZero() {
		return "0", "0", errors.New(errInvalidSwapAmount)
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	blockTimestamp := time.Now().Unix()
	poolSnapshot, observationsSnapshot := newDrySwapSnapshot(pool, blockTimestamp)

	slot0Start := poolSnapshot.Slot0()
	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	feeGrowthGlobalX128 := getFeeGrowthGlobal(poolSnapshot, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, poolSnapshot.Liquidity().Clone(), blockTimestamp, slot0Start)
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart, slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(zeroI256),
		InitialState:      state,
		Cache:             cache,
	}

	result, err := i.computeSwap(poolSnapshot, observationsSnapshot, comp, nil)
	if err != nil {
		return "0", "0", err
	}

	if zeroForOne {
		if poolSnapshot.BalanceToken1() < gnsmath.SafeConvertToInt64(result.Amount1.Abs()) {
			return "0", "0", errors.New(errInsufficientPoolBalance)
		}
	} else {
		if poolSnapshot.BalanceToken0() < gnsmath.SafeConvertToInt64(result.Amount0.Abs()) {
			return "0", "0", errors.New(errInsufficientPoolBalance)
		}
	}

	return result.Amount0.ToString(), result.Amount1.ToString(), nil
}

// tickCrossHookFn is invoked after an initialized tick is crossed. Swap uses it
// for externally visible side effects; DrySwap passes nil.
//
// Parameters:
//   - pool: Pool whose initialized tick was crossed; it contains the updated
//     in-memory tick and liquidity state visible to the callback.
//   - tickId: Index of the initialized tick that was crossed.
//   - zeroForOne: Swap direction; true moves toward lower ticks and false
//     moves toward higher ticks.
//   - timestamp: Block timestamp in Unix seconds for the crossing.
type tickCrossHookFn func(pool *pl.Pool, tickId int32, zeroForOne bool, timestamp int64)

// newDrySwapSnapshot builds the isolated pool and oracle state used by DrySwap.
//
// Pool.Clone copies the pool's scalar fields, while the tick tree and tick
// bitmap are copied separately because the swap loop rewrites and scans them.
// The observation tree starts fresh so simulation cannot extend stored oracle
// observations.
//
// Parameters:
//   - pool: Stored pool state to clone; its stored collections and scalar fields
//     are left unchanged.
//   - blockTimestamp: Unix-second timestamp used for the snapshot's initial
//     observation.
//
// Returns:
//   - *pl.Pool: Isolated pool snapshot with independently writable ticks and
//     tick bitmaps.
//   - *pl.ObservationTree: Fresh observation tree initialized at
//     blockTimestamp.
func newDrySwapSnapshot(pool *pl.Pool, blockTimestamp int64) (*pl.Pool, *pl.ObservationTree) {
	snapshot := pool.Clone()
	snapshot.SetTicks(copyPoolTicks(pool.Ticks()))
	snapshot.SetTickBitmaps(copyPoolTickBitmaps(pool.TickBitmaps()))
	slot0 := snapshot.Slot0()
	slot0.SetObservationIndex(0)
	slot0.SetObservationCardinality(1)
	slot0.SetObservationCardinalityNext(1)
	snapshot.SetSlot0(slot0)

	return snapshot, pl.NewPoolObservationsTree(blockTimestamp)
}

// copyPoolTicks copies a tick tree slot by slot. TickInfo is a value type, so
// the snapshot's writes replace its own slots and leave the source untouched.
//
// Parameters:
//   - src: Source tick tree to copy; nil is treated as an empty tree.
//
// Returns:
//   - *bptree.BPTree: Independent tick tree containing the source entries; a
//     nil source therefore produces an empty tree.
func copyPoolTicks(src *bptree.BPTree) *bptree.BPTree {
	copied := pl.NewPoolTicksTree()
	if src == nil {
		return copied
	}

	src.Iterate("", "", func(key string, value any) bool {
		copied.Set(key, value)
		return false
	})

	return copied
}

func copyPoolTickBitmaps(src map[int16]string) map[int16]string {
	copied := make(map[int16]string, len(src))
	for wordPos, bitmap := range src {
		copied[wordPos] = bitmap
	}

	return copied
}

func (i *poolV1) computeSwap(pool *pl.Pool, observations *pl.ObservationTree, comp SwapComputation, onTickCross tickCrossHookFn) (*SwapResult, error) {
	state := comp.InitialState
	var err error

	// Compute swap steps until completion
	for shouldContinueSwap(state, comp.SqrtPriceLimitX96) {
		state, err = i.computeSwapStep(state, pool, observations, comp.ZeroForOne, comp.SqrtPriceLimitX96, comp.ExactInput, comp.Cache, onTickCross)
		if err != nil {
			return nil, err
		}
	}

	// Calculate final amounts
	amount0 := state.amountCalculated
	amount1 := i256.Zero().Sub(comp.AmountSpecified, state.amountSpecifiedRemaining)
	if comp.ZeroForOne == comp.ExactInput {
		amount0, amount1 = amount1, amount0
	}

	// Prepare result
	result := &SwapResult{
		Amount0:              amount0,
		Amount1:              amount1,
		NewSqrtPrice:         state.sqrtPriceX96,
		NewTick:              state.tick,
		NewLiquidity:         state.liquidity,
		NewProtocolFeeToken0: pool.ProtocolFeesToken0(),
		NewProtocolFeeToken1: pool.ProtocolFeesToken1(),
		FeeGrowthGlobal0X128: pool.FeeGrowthGlobal0X128(),
		FeeGrowthGlobal1X128: pool.FeeGrowthGlobal1X128(),
	}

	// Update protocol fees if necessary
	if comp.ZeroForOne {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFeeToken0 = gnsmath.SafeAddInt64(result.NewProtocolFeeToken0, gnsmath.SafeConvertToInt64(state.protocolFee))
		}
		result.FeeGrowthGlobal0X128 = state.feeGrowthGlobalX128.Clone()
	} else {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFeeToken1 = gnsmath.SafeAddInt64(result.NewProtocolFeeToken1, gnsmath.SafeConvertToInt64(state.protocolFee))
		}
		result.FeeGrowthGlobal1X128 = state.feeGrowthGlobalX128.Clone()
	}

	return result, nil
}

// applySwapResult updates pool state with computed results.
// All state changes are applied at once to maintain consistency
//
// Parameters:
//   - pool: Pool whose slot0, liquidity, protocol-fee, and global fee-growth
//     fields are replaced in place.
//   - result: Completed swap result supplying the terminal state and fee
//     accumulators to apply atomically.
func applySwapResult(pool *pl.Pool, result *SwapResult) {
	slot0 := pool.Slot0()
	slot0.SetSqrtPriceX96(result.NewSqrtPrice)
	slot0.SetTick(result.NewTick)
	pool.SetSlot0(slot0)

	pool.SetLiquidity(result.NewLiquidity)
	pool.SetProtocolFeesToken0(result.NewProtocolFeeToken0)
	pool.SetProtocolFeesToken1(result.NewProtocolFeeToken1)
	pool.SetFeeGrowthGlobal0X128(result.FeeGrowthGlobal0X128)
	pool.SetFeeGrowthGlobal1X128(result.FeeGrowthGlobal1X128)
}

// validatePriceLimits ensures the provided price limit is valid for the swap direction
// The function enforces that:
// For zeroForOne (selling token0):
//   - Price limit must be below current price
//   - Price limit must be above MIN_SQRT_RATIO
//
// For !zeroForOne (selling token1):
//   - Price limit must be above current price
//   - Price limit must be below MAX_SQRT_RATIO
//
// Parameters:
//   - slot0: Current pool slot state whose square-root price is the reference.
//   - zeroForOne: Direction of the swap; true requires movement below the
//     current price, false requires movement above it.
//   - sqrtPriceLimitX96: Candidate Q96 square-root-price limit; it must remain
//     strictly between the directional current-price and protocol boundary.
func validatePriceLimits(slot0 pl.Slot0, zeroForOne bool, sqrtPriceLimitX96 *u256.Uint) {
	if zeroForOne {
		cond1 := sqrtPriceLimitX96.Lt(slot0.SqrtPriceX96())
		cond2 := sqrtPriceLimitX96.Gt(consts.MinSqrtRatio())
		if !(cond1 && cond2) {
			panic(newErrorWithDetail(
				errPriceOutOfRange,
				ufmt.Sprintf("sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > MIN_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					slot0.SqrtPriceX96().ToString(),
					sqrtPriceLimitX96.ToString(),
					MIN_SQRT_RATIO),
			))
		}
	} else {
		cond1 := sqrtPriceLimitX96.Gt(slot0.SqrtPriceX96())
		cond2 := sqrtPriceLimitX96.Lt(consts.MaxSqrtRatio())
		if !(cond1 && cond2) {
			panic(newErrorWithDetail(
				errPriceOutOfRange,
				ufmt.Sprintf("sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < MAX_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					slot0.SqrtPriceX96().ToString(),
					sqrtPriceLimitX96.ToString(),
					MAX_SQRT_RATIO),
			))
		}
	}
}

// getFeeProtocol returns the appropriate fee protocol based on zero for one.
// When zeroForOne is true, we want the lower 4 bits (% 16).
// Otherwise, we want the upper 4 bits (/ 16).
//
// Parameters:
//   - slot0: Pool slot state containing packed token0/token1 protocol-fee
//     divisors.
//   - zeroForOne: Selects the low four bits for token0 when true, or the high
//     four bits for token1 when false.
//
// Returns:
//   - uint8: Selected protocol-fee divisor; zero means no protocol fee is
//     charged for the direction.
func getFeeProtocol(slot0 pl.Slot0, zeroForOne bool) uint8 {
	shift := uint8(0)
	if !zeroForOne {
		shift = 4
	}
	return (slot0.FeeProtocol() >> shift) & uint8(0xF)
}

// getFeeGrowthGlobal returns the appropriate fee growth global based on zero for one.
//
// Parameters:
//   - pool: Pool whose global fee-growth accumulators are read.
//   - zeroForOne: Selects token0 growth when true and token1 growth otherwise.
//
// Returns:
//   - *u256.Uint: Clone of the selected global fee-growth accumulator in X128
//     precision.
func getFeeGrowthGlobal(pool *pl.Pool, zeroForOne bool) *u256.Uint {
	if zeroForOne {
		return pool.FeeGrowthGlobal0X128().Clone()
	}
	return pool.FeeGrowthGlobal1X128().Clone()
}

// shouldContinueSwap checks if swap should continue based on remaining amount and price limit.
//
// Parameters:
//   - state: Current swap state, including remaining specified amount and
//     square-root price.
//   - sqrtPriceLimitX96: Directional terminal Q96 square-root-price limit.
//
// Returns:
//   - bool: True while a nonzero amount remains and current price differs from
//     the limit; false when either stopping condition is met.
func shouldContinueSwap(state SwapState, sqrtPriceLimitX96 *u256.Uint) bool {
	return !state.amountSpecifiedRemaining.IsZero() && !state.sqrtPriceX96.Eq(sqrtPriceLimitX96)
}

// computeSwapStep executes a single step of swap and returns new state
//
// Parameters:
//   - state: Current swap state to advance by one liquidity segment.
//   - pool: Working pool supplying ticks, liquidity, fee growth, and protocol
//     fee state.
//   - observations: Oracle observation tree used when crossing an initialized
//     tick.
//   - zeroForOne: Swap direction; true moves toward lower ticks.
//   - sqrtPriceLimitX96: Directional terminal Q96 square-root-price limit.
//   - exactInput: True to consume an exact input amount; false to satisfy an
//     exact output amount.
//   - cache: Per-swap fee, liquidity, timestamp, and slot-start cache.
//   - onTickCross: Optional callback invoked after an initialized tick cross;
//     nil disables callback side effects.
//
// Returns:
//   - SwapState: State after this segment, or the input state when an error is
//     reported.
//   - error: Nil on success; non-nil for arithmetic or oracle failures.
func (i *poolV1) computeSwapStep(
	state SwapState,
	pool *pl.Pool,
	observations *pl.ObservationTree,
	zeroForOne bool,
	sqrtPriceLimitX96 *u256.Uint,
	exactInput bool,
	cache *SwapCache,
	onTickCross tickCrossHookFn,
) (SwapState, error) {
	step := computeSwapStepInit(state, pool, zeroForOne)

	// determining the price target for this step
	sqrtRatioTargetX96 := computeTargetSqrtRatio(step, sqrtPriceLimitX96, zeroForOne).Clone()

	// computing the amounts to be swapped at this step
	var (
		newState SwapState
		err      error
	)

	newState, step = computeAmounts(state, sqrtRatioTargetX96, pool, step)
	newState, err = updateAmounts(step, newState, exactInput)
	if err != nil {
		return state, err
	}

	// if the protocol fee is on, calculate how much is owed,
	// decrement fee amount, and increment protocol fee
	if cache.feeProtocol > 0 {
		newState, step, err = updateFeeProtocol(step, cache.feeProtocol, newState)
		if err != nil {
			return state, err
		}
	}

	// update global fee tracker
	if newState.liquidity.Gt(u256.Zero()) {
		update := u256.MulDiv(step.feeAmount, fixedPointQ128, newState.liquidity)
		feeGrowthGlobalX128 := u256.Zero().Add(newState.feeGrowthGlobalX128, update)
		newState.setFeeGrowthGlobalX128(feeGrowthGlobalX128)
	}

	// handling tick transitions
	if newState.sqrtPriceX96.Eq(step.sqrtPriceNextX96) {
		newState, err = i.tickTransition(step, zeroForOne, newState, pool, observations, cache, onTickCross)
		if err != nil {
			return state, err
		}
	} else if newState.sqrtPriceX96.Neq(step.sqrtPriceStartX96) {
		newState.setTick(gnsmath.TickMathGetTickAtSqrtRatio(newState.sqrtPriceX96))
	}

	return newState, nil
}

// updateFeeProtocol calculates and updates protocol fees for the current step.
//
// Parameters:
//   - step: Current step whose fee amount is reduced by the protocol share.
//   - feeProtocol: Nonzero protocol-fee divisor used to calculate the share.
//   - state: Current swap state whose accumulated protocol fee is increased.
//
// Returns:
//   - SwapState: State with the protocol fee accumulator increased.
//   - StepComputations: Step with the trader fee amount reduced by the protocol
//     share.
//   - error: Nil on success; non-nil when fee subtraction or protocol-fee
//     accumulation overflows or underflows.
func updateFeeProtocol(step StepComputations, feeProtocol uint8, state SwapState) (SwapState, StepComputations, error) {
	delta := u256.Zero().Div(step.feeAmount, u256.NewUint(uint64(feeProtocol)))

	newFeeAmount, overflow := u256.Zero().SubOverflow(step.feeAmount, delta)
	if overflow {
		return state, step, errors.New(errUnderflow)
	}

	step.feeAmount = newFeeAmount

	newProtocolFee, overflow := u256.Zero().AddOverflow(state.protocolFee, delta)
	if overflow {
		return state, step, errors.New(errOverflow)
	}
	state.protocolFee = newProtocolFee

	return state, step, nil
}

// computeSwapStepInit initializes the computation for a single swap step.
//
// Parameters:
//   - state: Current swap state supplying the starting square-root price and
//     tick.
//   - pool: Pool whose tick spacing and bitmap identify the next initialized
//     tick.
//   - zeroForOne: Swap direction used to search for the next tick.
//
// Returns:
//   - StepComputations: Step initialized with the start price, next tick,
//     initialization flag, and next-tick square-root price.
func computeSwapStepInit(state SwapState, pool *pl.Pool, zeroForOne bool) StepComputations {
	var step StepComputations
	step.sqrtPriceStartX96 = state.sqrtPriceX96
	tickNext, initialized := tickBitmapNextInitializedTickWithInOneWord(
		pool,
		state.tick,
		pool.TickSpacing(),
		zeroForOne,
	)

	step.tickNext = tickNext
	step.initialized = initialized

	// prevent overshoot the min/max tick
	step.clampTickNext()
	// get the price for the next tick
	step.sqrtPriceNextX96 = gnsmath.TickMathGetSqrtRatioAtTick(step.tickNext)
	return step
}

// computeTargetSqrtRatio determines the target sqrt price for the current swap step.
//
// Parameters:
//   - step: Step containing the next initialized tick's square-root price.
//   - sqrtPriceLimitX96: Directional terminal Q96 square-root-price limit.
//   - zeroForOne: Swap direction determining whether the lower or upper target
//     is reached first.
//
// Returns:
//   - *u256.Uint: Price limit when it is reached before the next tick, otherwise
//     the next tick's square-root price.
func computeTargetSqrtRatio(step StepComputations, sqrtPriceLimitX96 *u256.Uint, zeroForOne bool) *u256.Uint {
	if shouldUsePriceLimit(step.sqrtPriceNextX96, sqrtPriceLimitX96, zeroForOne) {
		return sqrtPriceLimitX96
	}
	return step.sqrtPriceNextX96
}

// shouldUsePriceLimit returns true if the price limit should be used instead of the next tick price
//
// Parameters:
//   - sqrtPriceNext: Candidate next-tick Q96 square-root price.
//   - sqrtPriceLimit: Directional terminal Q96 square-root-price limit.
//   - zeroForOne: Swap direction; true compares for downward movement, false
//     for upward movement.
//
// Returns:
//   - bool: True when the candidate tick price lies beyond the directional
//     limit and the limit must be used instead.
func shouldUsePriceLimit(sqrtPriceNext, sqrtPriceLimit *u256.Uint, zeroForOne bool) bool {
	if zeroForOne {
		return sqrtPriceNext.Lt(sqrtPriceLimit)
	}
	return sqrtPriceNext.Gt(sqrtPriceLimit)
}

// computeAmounts calculates the input and output amounts for the current swap step.
//
// Parameters:
//   - state: Current swap state containing price, liquidity, and remaining
//     signed amount.
//   - sqrtRatioTargetX96: Q96 square-root-price target for this step.
//   - pool: Pool supplying the fee tier used by swap math.
//   - step: Step whose input, output, and fee fields are populated.
//
// Returns:
//   - SwapState: State with its square-root price advanced to the computed step
//     price.
//   - StepComputations: Step populated with input amount, output amount, and
//     fee amount in base units.
func computeAmounts(state SwapState, sqrtRatioTargetX96 *u256.Uint, pool *pl.Pool, step StepComputations) (SwapState, StepComputations) {
	sqrtPriceX96, amountIn, amountOut, feeAmount := gnsmath.SwapMathComputeSwapStep(
		state.sqrtPriceX96,
		sqrtRatioTargetX96,
		state.liquidity,
		state.amountSpecifiedRemaining,
		uint64(pool.Fee()),
	)

	step.amountIn = amountIn
	step.amountOut = amountOut
	step.feeAmount = feeAmount

	state.setSqrtPriceX96(sqrtPriceX96)

	return state, step
}

// updateAmounts calculates new remaining and calculated amounts based on the swap step.
// For exact input swaps:
//   - Decrements remaining input amount by (amountIn + feeAmount)
//   - Decrements calculated amount by amountOut
//
// For exact output swaps:
//   - Increments remaining output amount by amountOut
//   - Increments calculated amount by (amountIn + feeAmount)
//
// Parameters:
//   - step: Computed input, output, and fee amounts for the current step.
//   - state: Current signed remaining and calculated amounts.
//   - exactInput: True subtracts input plus fee and output; false adds output
//     and input plus fee according to exact-output semantics.
//
// Returns:
//   - SwapState: State with checked remaining and calculated amounts updated.
//   - error: Nil on success; non-nil when int256 or int64 values overflow or
//     underflow.
func updateAmounts(step StepComputations, state SwapState, exactInput bool) (SwapState, error) {
	amountInWithFeeU256 := u256.Zero().Add(step.amountIn, step.feeAmount)
	if amountInWithFeeU256.Gt(maxInt256) {
		return state, errors.New(errOverflow)
	}

	amountInWithFee := i256.FromUint256(amountInWithFeeU256)
	if step.amountOut.Gt(maxInt256) {
		return state, errors.New(errOverflow)
	}

	var (
		amountSpecifiedRemaining *i256.Int
		amountCalculated         *i256.Int
		overflow                 bool
	)

	if exactInput {
		amountSpecifiedRemaining, overflow = i256.Zero().SubOverflow(state.amountSpecifiedRemaining, amountInWithFee)
		if overflow {
			return state, errors.New(errUnderflow)
		}
		amountCalculated, overflow = i256.Zero().SubOverflow(state.amountCalculated, i256.FromUint256(step.amountOut))
		if overflow {
			return state, errors.New(errUnderflow)
		}
	} else {
		amountSpecifiedRemaining, overflow = i256.Zero().AddOverflow(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
		if overflow {
			return state, errors.New(errOverflow)
		}
		amountCalculated, overflow = i256.Zero().AddOverflow(state.amountCalculated, amountInWithFee)
		if overflow {
			return state, errors.New(errOverflow)
		}
	}

	// If an overflowed value is stored in state, it may cause problems in the next step
	if amountCalculated.Gt(maxInt64) || amountSpecifiedRemaining.Gt(maxInt64) {
		return state, errors.New(errOverflow)
	}

	// If an underflowed value is stored in state, it may cause problems in the next step
	if amountCalculated.Lt(minInt64) || amountSpecifiedRemaining.Lt(minInt64) {
		return state, errors.New(errUnderflow)
	}

	state.amountSpecifiedRemaining = amountSpecifiedRemaining
	state.amountCalculated = amountCalculated

	return state, nil
}

// tickTransition handles the transition between price ticks during a swap
//
// Parameters:
//   - step: Step identifying the next tick and whether it is initialized.
//   - zeroForOne: Swap direction; true negates crossed liquidity net and moves
//     the active tick below the crossed tick.
//   - state: Current swap state to update with liquidity and tick changes.
//   - pool: Working pool whose crossed tick record and liquidity context are
//     read or updated.
//   - observations: Oracle tree used to compute latest cumulative values on
//     the first initialized cross.
//   - cache: Per-swap cache holding start slot, timestamp, liquidity, and
//     computed oracle values.
//   - onTickCross: Optional callback invoked after the tick is crossed; nil
//     skips callback execution.
//
// Returns:
//   - SwapState: State with crossed-tick liquidity and next active tick.
//   - error: Nil on success; non-nil when oracle observation or liquidity
//     transition computation fails.
func (i *poolV1) tickTransition(step StepComputations, zeroForOne bool, state SwapState, pool *pl.Pool, observations *pl.ObservationTree, cache *SwapCache, onTickCross tickCrossHookFn) (SwapState, error) {
	// ensure existing state to keep immutability
	newState := state

	if step.initialized {
		// Compute oracle values on first initialized tick cross
		if !cache.computedLatestObservation {
			tickCumulative, secondsPerLiquidityStr, err := observeSingle(
				observations,
				cache.blockTimestamp,
				0,
				cache.slot0Start.Tick(),
				cache.slot0Start.ObservationIndex(),
				cache.liquidityStart,
				cache.slot0Start.ObservationCardinality(),
			)
			if err != nil {
				return newState, err
			}

			cache.tickCumulative = tickCumulative
			cache.secondsPerLiquidityCumulativeX128 = u256.MustFromDecimal(secondsPerLiquidityStr)
			cache.computedLatestObservation = true
		}

		fee0, fee1 := u256.Zero(), u256.Zero()

		if zeroForOne {
			fee0 = state.feeGrowthGlobalX128
			fee1 = pool.FeeGrowthGlobal1X128()
		} else {
			fee0 = pool.FeeGrowthGlobal0X128()
			fee1 = state.feeGrowthGlobalX128
		}

		liquidityNet := tickCross(
			pool,
			step.tickNext,
			fee0,
			fee1,
			cache.secondsPerLiquidityCumulativeX128,
			cache.tickCumulative,
			cache.blockTimestamp,
		)

		if zeroForOne {
			liquidityNet = i256.Zero().Neg(liquidityNet)
		}

		newState.liquidity = gnsmath.LiquidityMathAddDelta(state.liquidity, liquidityNet)

		if onTickCross != nil {
			onTickCross(pool, step.tickNext, zeroForOne, cache.blockTimestamp)
		}
	}

	newState.tick = step.tickNext
	if zeroForOne {
		newState.tick = step.tickNext - 1
	}

	return newState, nil
}
