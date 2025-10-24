package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	plp "gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/pool"
)

const MAX_INT256 string = "57896044618658097711785492504343953926634992332820282019728792003956564819967"

// Hook functions allow external contracts to be notified of swap events.
var (
	// MUST BE IMMUTABLE.
	// DO NOT USE THIS VALUE IN ANY ARITHMETIC OPERATIONS' INITIALIZATION
	zero           = u256.Zero()
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
func (i *poolV1) SetTickCrossHook(hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsStakerWithVersion(1, caller)

	err := i.store.SetTickCrossHook(hook)
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
func (i *poolV1) SetSwapStartHook(hook func(poolPath string, timestamp int64)) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsStakerWithVersion(1, caller)

	err := i.store.SetSwapStartHook(hook)
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
func (i *poolV1) SetSwapEndHook(hook func(poolPath string) error) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsStakerWithVersion(1, caller)

	err := i.store.SetSwapEndHook(hook)
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
	NewProtocolFees      pl.ProtocolFees
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
	Cache             SwapCache
}

// SwapWithCallback executes a swap with callback pattern for optimistic transfers.
// This allows flash swaps where tokens are sent before payment is received.
//
// The flow is:
// 1. Pool sends output tokens to recipient
// 2. Pool calls callback on msg.sender
// 3. Callback must ensure pool receives input tokens
// 4. Pool validates its balance increased correctly
//
// Parameters:
//   - tokenIn: Input token path
//   - tokenOut: Output token path
//   - fee: Pool fee tier
//   - recipient: Address to receive output tokens
//   - zeroForOne: Direction of swap (true = token0 to token1)
//   - amountSpecified: Exact input (positive) or exact output (negative)
//   - sqrtPriceLimitX96: Price limit for the swap
//   - data: Arbitrary data passed to callback
//
// Returns amount0 and amount1 deltas as strings.
func (i *poolV1) Swap(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer address,
	swapCallback func(cur realm, amount0Delta, amount1Delta string) error,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	previousRealm := runtime.PreviousRealm()
	assertIsNotAllowedEOA(previousRealm)
	assertIsValidTokenOrder(token0Path, token1Path)

	if amountSpecified == "0" {
		panic(newErrorWithDetail(
			errInvalidSwapAmount,
			"amountSpecified == 0",
		))
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	slot0Start := pool.Slot0()
	if !slot0Start.Unlocked() {
		panic(errLockedPool)
	}

	// no liquidity -> no swap, return zero amounts
	if pool.Liquidity().IsZero() {
		return "0", "0"
	}

	slot0Start.SetUnlocked(false)

	// Call swap start hook if set
	if i.store.HasSwapStartHook() {
		swapStartHook := i.store.GetSwapStartHook()

		if swapStartHook != nil {
			currentTime := time.Now().Unix()
			swapStartHook(pool.PoolPath(), currentTime)
		}
	}

	defer func() {
		slot0Start.SetUnlocked(true)

		if i.store.HasSwapEndHook() {
			swapEndHook := i.store.GetSwapEndHook()

			if swapEndHook != nil {
				err := swapEndHook(pool.PoolPath())
				if err != nil {
					panic(err)
				}
			}
			err := swapEndHook(pool.PoolPath())
			if err != nil {
				panic(err)
			}
		}
	}()

	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	amounts := i256.MustFromDecimal(amountSpecified)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.Liquidity().Clone())
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart.Clone(), slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(i256.Zero()),
		InitialState:      state,
		Cache:             cache,
	}

	result, err := i.computeSwap(pool, comp)
	if err != nil {
		panic(err)
	}

	// Update oracle BEFORE applying swap result (using pre-swap state)
	if result.NewTick != pool.Slot0Tick() {
		currentTime := time.Now().Unix()

		err := writeObservationByPool(pool, currentTime, pool.Slot0Tick(), pool.Liquidity())
		if err != nil {
			panic(err)
		}
	}

	applySwapResult(pool, result)

	// transfer swap result to recipient then receive input tokens from swap callback
	if zeroForOne {
		// receive token0 from swap callback
		// send token1 to recipient (output)
		if result.Amount1.IsNeg() {
			i.safeSwapCallback(pool, token0Path, result.Amount0.Abs(), zeroForOne, swapCallback)

			i.safeTransfer(pool, recipient, token1Path, result.Amount1.Abs(), false)
		}
	} else {
		// receive token1 from swap callback
		// send token0 to recipient (output)
		if result.Amount0.IsNeg() {
			i.safeSwapCallback(pool, token1Path, result.Amount1.Abs(), zeroForOne, swapCallback)

			i.safeTransfer(pool, recipient, token0Path, result.Amount0.Abs(), true)
		}
	}

	lastObservation, err := lastObservation(pool.ObservationState())
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"Swap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", pool.PoolPath(),
		"zeroForOne", formatBool(zeroForOne),
		"requestAmount", amountSpecified,
		"sqrtPriceLimitX96", sqrtPriceLimitX96,
		"payer", payer.String(),
		"recipient", recipient.String(),
		"token0Amount", result.Amount0.ToString(),
		"token1Amount", result.Amount1.ToString(),
		"protocolFee0", pool.ProtocolFeesToken0().ToString(),
		"protocolFee1", pool.ProtocolFeesToken1().ToString(),
		"sqrtPriceX96", pool.Slot0SqrtPriceX96().ToString(),
		"exactIn", strconv.FormatBool(comp.ExactInput),
		"currentTick", strconv.FormatInt(int64(pool.Slot0Tick()), 10),
		"liquidity", pool.Liquidity().ToString(),
		"feeGrowthGlobal0X128", pool.FeeGrowthGlobal0X128().ToString(),
		"feeGrowthGlobal1X128", pool.FeeGrowthGlobal1X128().ToString(),
		"balanceToken0", pool.BalanceToken0().ToString(),
		"balanceToken1", pool.BalanceToken1().ToString(),
		"ticks", tickTreeToString(pool.Ticks()),
		"tickCumulative", formatInt(lastObservation.TickCumulative()),
		"liquidityCumulative", lastObservation.LiquidityCumulative().ToString(),
		"secondsPerLiquidityCumulativeX128", lastObservation.SecondsPerLiquidityCumulativeX128().ToString(),
		"observationTimestamp", formatInt(lastObservation.BlockTimestamp()),
	)

	return result.Amount0.ToString(), result.Amount1.ToString()
}

// DrySwap simulates a swap without modifying pool state.
// Returns amount0, amount1 and a success boolean.
// Returns false if pool is locked, has no liquidity, or computation fails.
func (i *poolV1) DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string, bool) {
	if amountSpecified == "0" {
		return "0", "0", false
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	// no liquidity -> simulation fails
	if pool.Liquidity().IsZero() {
		return "0", "0", false
	}

	slot0Start := pool.Slot0()
	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	amounts := i256.MustFromDecimal(amountSpecified)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.Liquidity().Clone())
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart, slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(i256.Zero()),
		InitialState:      state,
		Cache:             cache,
	}

	result, err := i.computeSwap(pool, comp)
	if err != nil {
		return "0", "0", false
	}

	if zeroForOne {
		if pool.BalanceToken1().Lt(result.Amount1.Abs()) {
			return "0", "0", false
		}
	} else {
		if pool.BalanceToken0().Lt(result.Amount0.Abs()) {
			return "0", "0", false
		}
	}

	// Validate that at least one amount is non-zero
	// Both amounts being zero indicates a failed swap
	if result.Amount0.IsZero() && result.Amount1.IsZero() {
		return "0", "0", false
	}

	return result.Amount0.ToString(), result.Amount1.ToString(), true
}

// computeSwap performs the core swap computation without modifying pool state.
// The computation continues until either:
// - The entire amount is consumed (amountSpecifiedRemaining = 0)
// - The price limit is reached (sqrtPriceX96 = sqrtPriceLimitX96)
//
// Important: This function is critical for AMM price discovery. It iterates through
// tick ranges, calculating swap amounts and fees for each liquidity segment.
// Returns an error if the computation fails at any step.
func (i *poolV1) computeSwap(pool *pl.Pool, comp SwapComputation) (*SwapResult, error) {
	state := comp.InitialState
	var err error

	// Compute swap steps until completion
	for shouldContinueSwap(state, comp.SqrtPriceLimitX96) {
		state, err = i.computeSwapStep(state, pool, comp.ZeroForOne, comp.SqrtPriceLimitX96, comp.ExactInput, comp.Cache)
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
		NewProtocolFees:      pool.ProtocolFees(),
		FeeGrowthGlobal0X128: pool.FeeGrowthGlobal0X128(),
		FeeGrowthGlobal1X128: pool.FeeGrowthGlobal1X128(),
	}

	// Update protocol fees if necessary
	if comp.ZeroForOne {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFees.Token0().Add(result.NewProtocolFees.Token0(), state.protocolFee)
		}
		result.FeeGrowthGlobal0X128 = state.feeGrowthGlobalX128.Clone()
	} else {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFees.Token1().Add(result.NewProtocolFees.Token1(), state.protocolFee)
		}
		result.FeeGrowthGlobal1X128 = state.feeGrowthGlobalX128.Clone()
	}

	return result, nil
}

// applySwapResult updates pool state with computed results.
// All state changes are applied at once to maintain consistency
func applySwapResult(pool *pl.Pool, result *SwapResult) {
	slot0 := pool.Slot0()
	slot0.SetSqrtPriceX96(result.NewSqrtPrice)
	slot0.SetTick(result.NewTick)
	pool.SetSlot0(slot0)

	pool.SetLiquidity(result.NewLiquidity)
	pool.SetProtocolFees(result.NewProtocolFees)
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
func validatePriceLimits(slot0 pl.Slot0, zeroForOne bool, sqrtPriceLimitX96 *u256.Uint) {
	if zeroForOne {
		cond1 := sqrtPriceLimitX96.Lt(slot0.SqrtPriceX96())
		cond2 := sqrtPriceLimitX96.Gt(minSqrtRatio)
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
		cond2 := sqrtPriceLimitX96.Lt(maxSqrtRatio)
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
func getFeeProtocol(slot0 pl.Slot0, zeroForOne bool) uint8 {
	shift := uint8(0)
	if !zeroForOne {
		shift = 4
	}
	return (slot0.FeeProtocol() >> shift) & uint8(0xF)
}

// getFeeGrowthGlobal returns the appropriate fee growth global based on zero for one.
func getFeeGrowthGlobal(pool *pl.Pool, zeroForOne bool) *u256.Uint {
	if zeroForOne {
		return pool.FeeGrowthGlobal0X128().Clone()
	}
	return pool.FeeGrowthGlobal1X128().Clone()
}

// shouldContinueSwap checks if swap should continue based on remaining amount and price limit.
func shouldContinueSwap(state SwapState, sqrtPriceLimitX96 *u256.Uint) bool {
	return !state.amountSpecifiedRemaining.IsZero() && !state.sqrtPriceX96.Eq(sqrtPriceLimitX96)
}

// computeSwapStep executes a single step of swap and returns new state
func (i *poolV1) computeSwapStep(
	state SwapState,
	pool *pl.Pool,
	zeroForOne bool,
	sqrtPriceLimitX96 *u256.Uint,
	exactInput bool,
	cache SwapCache,
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
		newState = i.tickTransition(step, zeroForOne, newState, pool)
	} else if newState.sqrtPriceX96.Neq(step.sqrtPriceStartX96) {
		newState.setTick(common.TickMathGetTickAtSqrtRatio(newState.sqrtPriceX96))
	}

	return newState, nil
}

// updateFeeProtocol calculates and updates protocol fees for the current step.
func updateFeeProtocol(step StepComputations, feeProtocol uint8, state SwapState) (SwapState, StepComputations, error) {
	delta := u256.Zero().Div(step.feeAmount, u256.NewUint(uint64(feeProtocol)))

	newFeeAmount, overflow := u256.Zero().SubOverflow(step.feeAmount, delta)
	if overflow {
		return state, step, errUnderflow
	}

	step.feeAmount = newFeeAmount

	newProtocolFee, overflow := u256.Zero().AddOverflow(state.protocolFee, delta)
	if overflow {
		return state, step, errOverFlow
	}
	state.protocolFee = newProtocolFee

	return state, step, nil
}

// computeSwapStepInit initializes the computation for a single swap step.
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
	sqrtPrice := common.TickMathGetSqrtRatioAtTick(step.tickNext).ToString()
	step.sqrtPriceNextX96 = u256.MustFromDecimal(sqrtPrice)
	return step
}

// computeTargetSqrtRatio determines the target sqrt price for the current swap step.
func computeTargetSqrtRatio(step StepComputations, sqrtPriceLimitX96 *u256.Uint, zeroForOne bool) *u256.Uint {
	if shouldUsePriceLimit(step.sqrtPriceNextX96, sqrtPriceLimitX96, zeroForOne) {
		return sqrtPriceLimitX96
	}
	return step.sqrtPriceNextX96
}

// shouldUsePriceLimit returns true if the price limit should be used instead of the next tick price
func shouldUsePriceLimit(sqrtPriceNext, sqrtPriceLimit *u256.Uint, zeroForOne bool) bool {
	if zeroForOne {
		return sqrtPriceNext.Lt(sqrtPriceLimit)
	}
	return sqrtPriceNext.Gt(sqrtPriceLimit)
}

// computeAmounts calculates the input and output amounts for the current swap step.
func computeAmounts(state SwapState, sqrtRatioTargetX96 *u256.Uint, pool *pl.Pool, step StepComputations) (SwapState, StepComputations) {
	sqrtPriceX96, amountIn, amountOut, feeAmount := plp.SwapMathComputeSwapStep(
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
func updateAmounts(step StepComputations, state SwapState, exactInput bool) (SwapState, error) {
	amountInWithFeeU256 := u256.Zero().Add(step.amountIn, step.feeAmount)
	if amountInWithFeeU256.Gt(maxInt256) {
		return state, errOverFlow
	}

	amountInWithFee := i256.FromUint256(amountInWithFeeU256)
	if step.amountOut.Gt(maxInt256) {
		return state, errOverFlow
	}

	var (
		amountSpecifiedRemaining *i256.Int
		amountCalculated         *i256.Int
		overflow                 bool
	)

	if exactInput {
		amountSpecifiedRemaining, overflow = i256.Zero().SubOverflow(state.amountSpecifiedRemaining, amountInWithFee)
		if overflow {
			return state, errUnderflow
		}
		amountCalculated, overflow = i256.Zero().SubOverflow(state.amountCalculated, i256.FromUint256(step.amountOut))
		if overflow {
			return state, errUnderflow
		}
	} else {
		amountSpecifiedRemaining, overflow = i256.Zero().AddOverflow(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
		if overflow {
			return state, errOverFlow
		}
		amountCalculated, overflow = i256.Zero().AddOverflow(state.amountCalculated, amountInWithFee)
		if overflow {
			return state, errOverFlow
		}
	}

	// If an overflowed value is stored in state, it may cause problems in the next step
	if amountCalculated.Gt(maxInt64) || amountSpecifiedRemaining.Gt(maxInt64) {
		return state, errOverFlow
	}

	// If an underflowed value is stored in state, it may cause problems in the next step
	if amountCalculated.Lt(minInt64) || amountSpecifiedRemaining.Lt(minInt64) {
		return state, errUnderflow
	}

	state.amountSpecifiedRemaining = amountSpecifiedRemaining
	state.amountCalculated = amountCalculated

	return state, nil
}

// tickTransition handles the transition between price ticks during a swap
func (i *poolV1) tickTransition(step StepComputations, zeroForOne bool, state SwapState, pool *pl.Pool) SwapState {
	// ensure existing state to keep immutability
	newState := state

	if step.initialized {
		fee0, fee1 := u256.Zero(), u256.Zero()

		if zeroForOne {
			fee0 = state.feeGrowthGlobalX128
			fee1 = pool.FeeGrowthGlobal1X128()
		} else {
			fee0 = pool.FeeGrowthGlobal0X128()
			fee1 = state.feeGrowthGlobalX128
		}

		liquidityNet := tickCross(pool, step.tickNext, fee0, fee1)

		if zeroForOne {
			liquidityNet = i256.Zero().Neg(liquidityNet)
		}

		newState.liquidity = common.LiquidityMathAddDelta(state.liquidity, liquidityNet)

		if i.store.HasTickCrossHook() {
			tickCrossHook := i.store.GetTickCrossHook()

			currentTime := time.Now().Unix()
			tickCrossHook(pool.PoolPath(), step.tickNext, zeroForOne, currentTime)
		}
	}

	decrement := int32(0)
	if zeroForOne {
		decrement = 1
	}
	newState.tick = step.tickNext - decrement

	return newState
}
