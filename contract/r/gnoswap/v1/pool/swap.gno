package pool

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	plp "gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

const MAX_INT256 string = "57896044618658097711785492504343953926634992332820282019728792003956564819967"

// Hook functions allow external contracts to be notified of swap events.
var (
	// MUST BE IMMUTABLE.
	// DO NOT USE THIS VALUE IN ANY ARITHMETIC OPERATIONS' INITIALIZATION
	zero           = u256.Zero()
	fixedPointQ128 = u256.MustFromDecimal(Q128)

	maxInt256 = u256.MustFromDecimal(MAX_INT256)
	maxInt64  = i256.MustFromDecimal(MAX_INT64)

	swapStartHook func(poolPath string, timestamp int64)
	tickCrossHook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)
	swapEndHook   func(poolPath string) error
)

// SetTickCrossHook sets the hook function called when a tick is crossed during swaps.
//
// Allows staker to monitor liquidity changes at price levels.
// Used for reward calculation when positions enter/exit range.
//
// Only callable by staker contract.
func SetTickCrossHook(cur realm, hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)
	tickCrossHook = hook
}

// SetSwapStartHook sets the hook function called at the beginning of a swap.
//
// Enables pre-swap state tracking for reward distribution.
// Captures timestamp for time-weighted calculations.
//
// Only callable by staker contract.
func SetSwapStartHook(cur realm, hook func(poolPath string, timestamp int64)) {
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)
	swapStartHook = hook
}

// SetSwapEndHook sets the hook function called at the end of a swap.
//
// Finalizes reward calculations after swap completion.
// Allows error propagation to revert invalid swaps.
//
// Only callable by staker contract.
func SetSwapEndHook(cur realm, hook func(poolPath string) error) {
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)
	swapEndHook = hook
}

// SwapResult encapsulates all state changes from a swap.
// It ensures atomic state transitions that can be applied at once.
type SwapResult struct {
	Amount0              *i256.Int
	Amount1              *i256.Int
	NewSqrtPrice         *u256.Uint
	NewTick              int32
	NewLiquidity         *u256.Uint
	NewProtocolFees      ProtocolFees
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

// Swap executes a token swap in the pool.
//
// Parameters:
//   - token0Path, token1Path: token contract paths
//   - fee: pool fee tier
//   - recipient: address receiving output tokens
//   - zeroForOne: true for token0→token1, false for token1→token0
//   - amountSpecified: amount to swap (positive=exact in, negative=exact out)
//   - sqrtPriceLimitX96: price limit in Q96 format
//   - payer: address paying input tokens
//
// Returns amount0, amount1 as decimal strings (negative for tokens out).
// Only callable by whitelisted routers.
// Note: Uses tick-based pricing with Q96 fixed-point math.
func Swap(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer std.Address, // router
) (string, string) {
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsSwapWhitelisted(caller)
	assertPayerIsPreviousRealmOrOriginCaller(payer)

	if amountSpecified == "0" {
		panic(newErrorWithDetail(
			errInvalidSwapAmount,
			"amountSpecified == 0",
		))
	}

	pool := mustGetPoolBy(token0Path, token1Path, fee)

	slot0Start := pool.slot0
	if !slot0Start.unlocked {
		panic(errLockedPool)
	}

	// no liquidity -> no swap, return zero amounts
	if pool.liquidity.IsZero() {
		return "0", "0"
	}

	pool.slot0.unlocked = false

	// Call swap start hook if set
	if swapStartHook != nil {
		currentTime := time.Now().Unix()
		swapStartHook(pool.PoolPath(), currentTime)
	}

	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	amounts := i256.MustFromDecimal(amountSpecified)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.liquidity.Clone())
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart.Clone(), slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(i256.Zero()),
		InitialState:      state,
		Cache:             cache,
	}

	result, err := computeSwap(pool, comp)
	if err != nil {
		panic(err)
	}

	applySwapResult(pool, result)

	// update TWAP state
	currentTime := time.Now().Unix()
	pool.updatePriceCumulatives(currentTime)

	// actual swap
	pool.swapTransfers(zeroForOne, payer, recipient, result.Amount0, result.Amount1)

	pool.slot0.unlocked = true
	// Call swap end hook if set
	if swapEndHook != nil {
		err := swapEndHook(pool.PoolPath())
		if err != nil {
			panic(err)
		}
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"Swap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", GetPoolPath(token0Path, token1Path, fee),
		"zeroForOne", formatBool(zeroForOne),
		"requestAmount", amountSpecified,
		"sqrtPriceLimitX96", sqrtPriceLimitX96,
		"payer", payer.String(),
		"recipient", recipient.String(),
		"token0Amount", result.Amount0.ToString(),
		"token1Amount", result.Amount1.ToString(),
		"protocolFee0", pool.protocolFees.token0.ToString(),
		"protocolFee1", pool.protocolFees.token1.ToString(),
		"sqrtPriceX96", pool.slot0.sqrtPriceX96.ToString(),
		"exactIn", strconv.FormatBool(comp.ExactInput),
		"currentTick", strconv.FormatInt(int64(pool.Slot0Tick()), 10),
		"liquidity", pool.Liquidity().ToString(),
		"feeGrowthGlobal0X128", pool.FeeGrowthGlobal0X128().ToString(),
		"feeGrowthGlobal1X128", pool.FeeGrowthGlobal1X128().ToString(),
		"balanceToken0", pool.BalanceToken0().ToString(),
		"balanceToken1", pool.BalanceToken1().ToString(),
		"ticks", pool.Ticks(),
		"tickCumulative", formatInt(pool.Observation().TickCumulative()),
		"liquidityCumulative", pool.Observation().LiquidityCumulative(),
		"lastCumulativeUpdateTime", formatInt(pool.Observation().LastCumulativeUpdateTime()),
	)

	return result.Amount0.ToString(), result.Amount1.ToString()
}

// DrySwap simulates a swap without modifying pool state.
// Returns amount0, amount1 and a success boolean.
// Returns false if pool is locked, has no liquidity, or computation fails.
func DrySwap(
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

	pool := mustGetPoolBy(token0Path, token1Path, fee)

	// no liquidity -> simulation fails
	if pool.liquidity.IsZero() {
		return "0", "0", false
	}

	slot0Start := pool.slot0
	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)
	validatePriceLimits(slot0Start, zeroForOne, sqrtPriceLimit)

	amounts := i256.MustFromDecimal(amountSpecified)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.liquidity.Clone())
	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart, slot0Start)

	comp := SwapComputation{
		AmountSpecified:   amounts,
		SqrtPriceLimitX96: sqrtPriceLimit,
		ZeroForOne:        zeroForOne,
		ExactInput:        amounts.Gt(i256.Zero()),
		InitialState:      state,
		Cache:             cache,
	}

	result, err := computeSwap(pool, comp)
	if err != nil {
		return "0", "0", false
	}

	if zeroForOne {
		if pool.balances.token1.Lt(result.Amount1.Abs()) {
			return "0", "0", false
		}
	} else {
		if pool.balances.token0.Lt(result.Amount0.Abs()) {
			return "0", "0", false
		}
	}

	// Validate non-zero amounts
	if result.Amount0.IsZero() || result.Amount1.IsZero() {
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
func computeSwap(pool *Pool, comp SwapComputation) (*SwapResult, error) {
	state := comp.InitialState
	var err error

	// Compute swap steps until completion
	for shouldContinueSwap(state, comp.SqrtPriceLimitX96) {
		state, err = computeSwapStep(state, pool, comp.ZeroForOne, comp.SqrtPriceLimitX96, comp.ExactInput, comp.Cache)
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
		Amount0:      amount0,
		Amount1:      amount1,
		NewSqrtPrice: state.sqrtPriceX96,
		NewTick:      state.tick,
		NewLiquidity: state.liquidity,
		NewProtocolFees: ProtocolFees{
			token0: pool.protocolFees.token0,
			token1: pool.protocolFees.token1,
		},
		FeeGrowthGlobal0X128: pool.feeGrowthGlobal0X128,
		FeeGrowthGlobal1X128: pool.feeGrowthGlobal1X128,
	}

	// Update protocol fees if necessary
	if comp.ZeroForOne {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFees.token0 = u256.Zero().Add(result.NewProtocolFees.token0, state.protocolFee)
		}
		result.FeeGrowthGlobal0X128 = state.feeGrowthGlobalX128.Clone()
	} else {
		if state.protocolFee.Gt(zero) {
			result.NewProtocolFees.token1 = u256.Zero().Add(result.NewProtocolFees.token1, state.protocolFee)
		}
		result.FeeGrowthGlobal1X128 = state.feeGrowthGlobalX128.Clone()
	}

	return result, nil
}

// applySwapResult updates pool state with computed results.
// All state changes are applied at once to maintain consistency
func applySwapResult(pool *Pool, result *SwapResult) {
	pool.slot0.sqrtPriceX96 = result.NewSqrtPrice
	pool.slot0.tick = result.NewTick
	pool.liquidity = result.NewLiquidity
	pool.protocolFees = result.NewProtocolFees
	pool.feeGrowthGlobal0X128 = result.FeeGrowthGlobal0X128
	pool.feeGrowthGlobal1X128 = result.FeeGrowthGlobal1X128
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
func validatePriceLimits(slot0 Slot0, zeroForOne bool, sqrtPriceLimitX96 *u256.Uint) {
	if zeroForOne {
		cond1 := sqrtPriceLimitX96.Lt(slot0.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Gt(minSqrtRatio)
		if !(cond1 && cond2) {
			panic(newErrorWithDetail(
				errPriceOutOfRange,
				ufmt.Sprintf("sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > MIN_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					slot0.sqrtPriceX96.ToString(),
					sqrtPriceLimitX96.ToString(),
					MIN_SQRT_RATIO),
			))
		}
	} else {
		cond1 := sqrtPriceLimitX96.Gt(slot0.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Lt(maxSqrtRatio)
		if !(cond1 && cond2) {
			panic(newErrorWithDetail(
				errPriceOutOfRange,
				ufmt.Sprintf("sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < MAX_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					slot0.sqrtPriceX96.ToString(),
					sqrtPriceLimitX96.ToString(),
					MAX_SQRT_RATIO),
			))
		}
	}
}

// getFeeProtocol returns the appropriate fee protocol based on zero for one.
// When zeroForOne is true, we want the lower 4 bits (% 16).
// Otherwise, we want the upper 4 bits (/ 16).
func getFeeProtocol(slot0 Slot0, zeroForOne bool) uint8 {
	shift := uint8(0)
	if !zeroForOne {
		shift = 4
	}
	return (slot0.feeProtocol >> shift) & uint8(0xF)
}

// getFeeGrowthGlobal returns the appropriate fee growth global based on zero for one.
func getFeeGrowthGlobal(pool *Pool, zeroForOne bool) *u256.Uint {
	if zeroForOne {
		return pool.feeGrowthGlobal0X128.Clone()
	}
	return pool.feeGrowthGlobal1X128.Clone()
}

// shouldContinueSwap checks if swap should continue based on remaining amount and price limit.
func shouldContinueSwap(state SwapState, sqrtPriceLimitX96 *u256.Uint) bool {
	return !state.amountSpecifiedRemaining.IsZero() && !state.sqrtPriceX96.Eq(sqrtPriceLimitX96)
}

// computeSwapStep executes a single step of swap and returns new state
func computeSwapStep(
	state SwapState,
	pool *Pool,
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
		newState = tickTransition(step, zeroForOne, newState, pool)
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
func computeSwapStepInit(state SwapState, pool *Pool, zeroForOne bool) StepComputations {
	var step StepComputations
	step.sqrtPriceStartX96 = state.sqrtPriceX96
	tickNext, initialized := pool.tickBitmapNextInitializedTickWithInOneWord(
		state.tick,
		pool.tickSpacing,
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
func computeAmounts(state SwapState, sqrtRatioTargetX96 *u256.Uint, pool *Pool, step StepComputations) (SwapState, StepComputations) {
	sqrtPriceX96, amountIn, amountOut, feeAmount := plp.SwapMathComputeSwapStep(
		state.sqrtPriceX96,
		sqrtRatioTargetX96,
		state.liquidity,
		state.amountSpecifiedRemaining,
		uint64(pool.fee),
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
		return state, errUnderflow
	}

	var (
		amountSpecifiedRemaining *i256.Int
		amountCalculated         *i256.Int
	)

	if exactInput {
		amountSpecifiedRemaining = i256.Zero().Sub(state.amountSpecifiedRemaining, amountInWithFee)
		amountCalculated = i256.Zero().Sub(state.amountCalculated, i256.FromUint256(step.amountOut))
	} else {
		amountSpecifiedRemaining = i256.Zero().Add(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
		amountCalculated = i256.Zero().Add(state.amountCalculated, amountInWithFee)
	}

	// If an overflowed value is stored in state, it may cause problems in the next step
	if amountCalculated.Gt(maxInt64) {
		return state, errOverFlow
	}

	state.amountSpecifiedRemaining = amountSpecifiedRemaining
	state.amountCalculated = amountCalculated

	return state, nil
}

// tickTransition handles the transition between price ticks during a swap
func tickTransition(step StepComputations, zeroForOne bool, state SwapState, pool *Pool) SwapState {
	// ensure existing state to keep immutability
	newState := state

	if step.initialized {
		fee0, fee1 := u256.Zero(), u256.Zero()

		if zeroForOne {
			fee0 = state.feeGrowthGlobalX128
			fee1 = pool.feeGrowthGlobal1X128
		} else {
			fee0 = pool.feeGrowthGlobal0X128
			fee1 = state.feeGrowthGlobalX128
		}

		liquidityNet := pool.tickCross(step.tickNext, fee0, fee1)

		if zeroForOne {
			liquidityNet = i256.Zero().Neg(liquidityNet)
		}

		newState.liquidity = liquidityMathAddDelta(state.liquidity, liquidityNet)

		if tickCrossHook != nil {
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

// swapTransfers handles token transfers for a swap transaction.
// For zeroForOne swaps: transfers token0 from payer to pool and token1 from pool to recipient.
// For oneForZero swaps: transfers token1 from payer to pool and token0 from pool to recipient.
func (p *Pool) swapTransfers(zeroForOne bool, payer, recipient std.Address, amount0, amount1 *i256.Int) {
	if zeroForOne {
		// payer > POOL
		p.safeTransferFrom(payer, poolAddr, p.token0Path, amount0.Abs(), true)

		// POOL > recipient
		p.safeTransfer(recipient, p.token1Path, amount1, false)
	} else {
		// payer > POOL
		p.safeTransferFrom(payer, poolAddr, p.token1Path, amount1.Abs(), false)
		// POOL > recipient
		p.safeTransfer(recipient, p.token0Path, amount0, true)
	}
}
