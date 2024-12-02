package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	plp "gno.land/p/gnoswap/pool"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Mint creates a new position and mints liquidity tokens.
// Returns minted amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#mint
func Mint(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	_liquidityAmount string,
	positionCaller std.Address,
) (string, string) {
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Mint() || only position(%s) can call pool mint(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)
	if liquidityAmount.IsZero() {
		panic(addDetailToError(
			errZeroLiquidity,
			ufmt.Sprintf("pool.gno__Mint() || liquidityAmount == 0"),
		))
	}

	pool := GetPool(token0Path, token1Path, fee)
	position := newModifyPositionParams(recipient, tickLower, tickUpper, i256.FromUint256(liquidityAmount))
	_, amount0, amount1 := pool.modifyPosition(position)

	if amount0.Gt(u256.Zero()) {
		pool.transferFromAndVerify(positionCaller, consts.POOL_ADDR, pool.token0Path, amount0, true)
	}

	if amount1.Gt(u256.Zero()) {
		pool.transferFromAndVerify(positionCaller, consts.POOL_ADDR, pool.token1Path, amount1, false)
	}

	return amount0.ToString(), amount1.ToString()
}

// Burn removes liquidity from the caller and account tokens owed for the liquidity to the position
// If liquidity of 0 is burned, it recalculates fees owed to a position
// Returns burned amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#burn
func Burn(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string, // uint128
) (string, string) { // uint256 x2
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if common.GetLimitCaller() {
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Burn() || only position(%s) can call pool burn(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liqAmount := u256.MustFromDecimal(liquidityAmount)

	pool := GetPool(token0Path, token1Path, fee)

	liqDelta := i256.Zero().Neg(i256.FromUint256(liqAmount))
	posParams := newModifyPositionParams(caller, tickLower, tickUpper, liqDelta)
	position, amount0, amount1 := pool.modifyPosition(posParams)

	if amount0.Gt(u256.Zero()) || amount1.Gt(u256.Zero()) {
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, amount0)
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, amount1)
	}

	positionKey := positionGetKey(caller, tickLower, tickUpper)
	pool.positions[positionKey] = position

	// actual token transfer happens in Collect()
	return amount0.ToString(), amount1.ToString()
}

// Collect collects tokens owed to a position
// Burned amounts, and swap fees will be transferred to the caller
// Returns collected amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#collect
func Collect(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Collect() || only position(%s) can call pool collect(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool.gno__Collect() || positionKey(%s) does not exist", positionKey),
		))
	}

	var amount0, amount1 *u256.Uint

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0, position.tokensOwed0, pool.balances.token0 = collectToken(amount0Req, position.tokensOwed0, pool.balances.token0)
	token0 := common.GetToken(pool.token0Path)
	checkTransferError(token0.Transfer(recipient, amount0.Uint64()))

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1, position.tokensOwed1, pool.balances.token1 = collectToken(amount1Req, position.tokensOwed1, pool.balances.token1)

	// Update state first then transfer
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1)
	pool.balances.token1 = new(u256.Uint).Sub(pool.balances.token1, amount1)
	token1 := common.GetToken(pool.token1Path)
	checkTransferError(token1.Transfer(recipient, amount1.Uint64()))

	pool.positions[positionKey] = position

	return amount0.ToString(), amount1.ToString()
}

// collectToken handles the collection of a single token type (token0 or token1)
func collectToken(
	amountReq, tokensOwed, poolBalance *u256.Uint,
) (amount, newTokensOwed, newPoolBalance *u256.Uint) {
	// find smallest of three amounts
	amount = u256Min(amountReq, tokensOwed)
	amount = u256Min(amount, poolBalance)

	// value for update state
	newTokensOwed = new(u256.Uint).Sub(tokensOwed, amount)
	newPoolBalance = new(u256.Uint).Sub(poolBalance, amount)

	return amount, newTokensOwed, newPoolBalance
}

// SwapResult encapsulates all state changes that occur as a result of a swap
// This type ensure all state transitions are atomic and can be applied at once.
type SwapResult struct {
	Amount0              *i256.Int
	Amount1              *i256.Int
	NewSqrtPrice         *u256.Uint
	NewTick              int32
	NewLiquidity         *u256.Uint
	NewProtocolFees      ProtocolFees
	FeeGrowthGlobal0X128 *u256.Uint
	FeeGrowthGlobal1X128 *u256.Uint
	SwapFee              *u256.Uint
}

// SwapComputation encapsulates pure computation logic for swap
type SwapComputation struct {
	AmountSpecified   *i256.Int
	SqrtPriceLimitX96 *u256.Uint
	ZeroForOne        bool
	ExactInput        bool
	InitialState      SwapState
	Cache             SwapCache
}

// Swap swaps token0 for token1, or token1 for token0
// Returns swapped amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#swap
func Swap(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer std.Address, // router
) (string, string) {
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if err := common.RouterOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Swap() || only router(%s) can call pool swap(), called from %s", consts.ROUTER_ADDR, caller.String()),
			))
		}
	}

	if amountSpecified == "0" {
		panic(addDetailToError(
			errInvalidSwapAmount,
			ufmt.Sprintf("pool.gno__Swap() || amountSpecified == 0"),
		))
	}

	pool := GetPool(token0Path, token1Path, fee)

	slot0Start := pool.slot0
	if !slot0Start.unlocked {
		panic(errLockedPool)
	}

	slot0Start.unlocked = false
	defer func() { slot0Start.unlocked = true }()

	amounts := i256.MustFromDecimal(amountSpecified)
	sqrtPriceLimit := u256.MustFromDecimal(sqrtPriceLimitX96)

	validatePriceLimits(pool, zeroForOne, sqrtPriceLimit)

	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.liquidity)

	state := newSwapState(amounts, feeGrowthGlobalX128, cache.liquidityStart, pool.slot0)

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

	// actual swap
	pool.swapTransfers(zeroForOne, payer, recipient, result.Amount0, result.Amount1)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"Swap",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", GetPoolPath(token0Path, token1Path, fee),
		"zeroForOne", ufmt.Sprintf("%t", zeroForOne),
		"amountSpecified", amountSpecified,
		"sqrtPriceLimitX96", sqrtPriceLimitX96,
		"payer", payer.String(),
		"recipient", recipient.String(),
		"internal_amount0", result.Amount0.ToString(),
		"internal_amount1", result.Amount1.ToString(),
		"internal_protocolFee0", pool.protocolFees.token0.ToString(),
		"internal_protocolFee1", pool.protocolFees.token1.ToString(),
		"internal_swapFee", result.SwapFee.ToString(),
		"internal_sqrtPriceX96", pool.slot0.sqrtPriceX96.ToString(),
	)

	return result.Amount0.ToString(), result.Amount1.ToString()
}

// computeSwap performs the core swap computation without modifying pool state
// The function follows these state transitions:
// 1. Initial State: Provided by `SwapComputation.InitialState`
// 2. Stepping State: For each step:
//   - Compute next tick and price target
//   - Calculate amounts and fees
//   - Update state (remaining amount, fees, liquidity)
//   - Handle tick transitions if necessary
//
// 3. Final State: Aggregated in SwapResult
//
// The computation continues until either:
// - The entire amount is consumed (`amountSpecifiedRemaining` = 0)
// - The price limit is reached (`sqrtPriceX96` = `sqrtPriceLimitX96`)
//
// Returns an error if the computation fails at any step
func computeSwap(pool *Pool, comp SwapComputation) (*SwapResult, error) {
	state := comp.InitialState
	swapFee := u256.Zero()

	var newFee *u256.Uint
	var err error

	// Compute swap steps until completion
	for shouldContinueSwap(state, comp.SqrtPriceLimitX96) {
		state, newFee, err = computeSwapStep(state, pool, comp.ZeroForOne, comp.SqrtPriceLimitX96, comp.ExactInput, comp.Cache, swapFee)
		if err != nil {
			return nil, err
		}
		swapFee = newFee
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
		SwapFee:              swapFee,
	}

	// Update protocol fees if necessary
	if comp.ZeroForOne {
		if state.protocolFee.Gt(u256.Zero()) {
			result.NewProtocolFees.token0 = new(u256.Uint).Add(result.NewProtocolFees.token0, state.protocolFee)
		}
		result.FeeGrowthGlobal0X128 = state.feeGrowthGlobalX128
	} else {
		if state.protocolFee.Gt(u256.Zero()) {
			result.NewProtocolFees.token1 = new(u256.Uint).Add(result.NewProtocolFees.token1, state.protocolFee)
		}
		result.FeeGrowthGlobal1X128 = state.feeGrowthGlobalX128
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
func validatePriceLimits(pool *Pool, zeroForOne bool, sqrtPriceLimitX96 *u256.Uint) {
	if zeroForOne {
		minSqrtRatio := u256.MustFromDecimal(consts.MIN_SQRT_RATIO)

		cond1 := sqrtPriceLimitX96.Lt(pool.slot0.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Gt(minSqrtRatio)
		if !(cond1 && cond2) {
			panic(addDetailToError(
				errPriceOutOfRange,
				ufmt.Sprintf("pool.gno__Swap() || sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > consts.MIN_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					pool.slot0.sqrtPriceX96.ToString(),
					sqrtPriceLimitX96.ToString(),
					consts.MIN_SQRT_RATIO),
			))
		}
	} else {
		maxSqrtRatio := u256.MustFromDecimal(consts.MAX_SQRT_RATIO)

		cond1 := sqrtPriceLimitX96.Gt(pool.slot0.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Lt(maxSqrtRatio)
		if !(cond1 && cond2) {
			panic(addDetailToError(
				errPriceOutOfRange,
				ufmt.Sprintf("pool.gno__Swap() || sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < consts.MAX_SQRT_RATIO(%s)",
					sqrtPriceLimitX96.ToString(),
					pool.slot0.sqrtPriceX96.ToString(),
					sqrtPriceLimitX96.ToString(),
					consts.MAX_SQRT_RATIO),
			))
		}
	}
}

// getFeeProtocol returns the appropriate fee protocol based on zero for one
func getFeeProtocol(slot0 Slot0, zeroForOne bool) uint8 {
	if zeroForOne {
		return slot0.feeProtocol % 16
	}
	return slot0.feeProtocol / 16
}

// getFeeGrowthGlobal returns the appropriate fee growth global based on zero for one
func getFeeGrowthGlobal(pool *Pool, zeroForOne bool) *u256.Uint {
	if zeroForOne {
		return pool.feeGrowthGlobal0X128
	}
	return pool.feeGrowthGlobal1X128
}

func shouldContinueSwap(state SwapState, sqrtPriceLimitX96 *u256.Uint) bool {
	return !(state.amountSpecifiedRemaining.IsZero()) && !(state.sqrtPriceX96.Eq(sqrtPriceLimitX96))
}

// computeSwapStep executes a single step of swap and returns new state
func computeSwapStep(
	state SwapState,
	pool *Pool,
	zeroForOne bool,
	sqrtPriceLimitX96 *u256.Uint,
	exactInput bool,
	cache SwapCache,
	swapFee *u256.Uint,
) (SwapState, *u256.Uint, error) {
	step := computeSwapStepInit(state, pool, zeroForOne)

	// determining the price target for this step
	sqrtRatioTargetX96 := computeTargetSqrtRatio(step, sqrtPriceLimitX96, zeroForOne)

	// computing the amounts to be swapped at this step
	var newState SwapState
	var err error

	newState, step = computeAmounts(state, sqrtRatioTargetX96, pool, step)
	newState = updateAmounts(step, newState, exactInput)

	// if the protocol fee is on, calculate how much is owed,
	// decrement fee amount, and increment protocol fee
	if cache.feeProtocol > 0 {
		newState, err = updateFeeProtocol(step, cache.feeProtocol, newState)
		if err != nil {
			return state, nil, err
		}
	}

	// update global fee tracker
	if newState.liquidity.Gt(u256.Zero()) {
		update := u256.MulDiv(step.feeAmount, u256.MustFromDecimal(consts.Q128), newState.liquidity)
		newState.SetFeeGrowthGlobalX128(new(u256.Uint).Add(newState.feeGrowthGlobalX128, update))
	}

	// handling tick transitions
	if newState.sqrtPriceX96.Eq(step.sqrtPriceNextX96) {
		newState = tickTransition(step, zeroForOne, newState, pool)
	}

	if newState.sqrtPriceX96.Neq(step.sqrtPriceStartX96) {
		newState.SetTick(common.TickMathGetTickAtSqrtRatio(newState.sqrtPriceX96))
	}

	newSwapFee := new(u256.Uint).Add(swapFee, step.feeAmount)

	return newState, newSwapFee, nil
}

// updateFeeProtocol calculates and updates protocol fees for the current step.
func updateFeeProtocol(step StepComputations, feeProtocol uint8, state SwapState) (SwapState, error) {
	delta := step.feeAmount
	delta.Div(delta, u256.NewUint(uint64(feeProtocol)))

	newFeeAmount, overflow := new(u256.Uint).SubOverflow(step.feeAmount, delta)
	if overflow {
		return state, errUnderflow
	}
	step.feeAmount = newFeeAmount
	state.protocolFee.Add(state.protocolFee, delta)

	return state, nil
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
	step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)
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
	isLower := sqrtPriceNext.Lt(sqrtPriceLimit)
	isHigher := sqrtPriceNext.Gt(sqrtPriceLimit)
	if zeroForOne {
		return isLower
	}
	return isHigher
}

// computeAmounts calculates the input and output amounts for the current swap step.
func computeAmounts(state SwapState, sqrtRatioTargetX96 *u256.Uint, pool *Pool, step StepComputations) (SwapState, StepComputations) {
	sqrtPriceX96Str, amountInStr, amountOutStr, feeAmountStr := plp.SwapMathComputeSwapStepStr(
		state.sqrtPriceX96,
		sqrtRatioTargetX96,
		state.liquidity,
		state.amountSpecifiedRemaining,
		uint64(pool.fee),
	)

	step.amountIn = u256.MustFromDecimal(amountInStr)
	step.amountOut = u256.MustFromDecimal(amountOutStr)
	step.feeAmount = u256.MustFromDecimal(feeAmountStr)

	state.SetSqrtPriceX96(sqrtPriceX96Str)

	return state, step
}

// updateAmounts calculates new remaining and calculated amounts based on the swap step
// For exact input swaps:
//   - Decrements remaining input amount by (amountIn + feeAmount)
//   - Decrements calculated amount by amountOut
//
// For exact output swaps:
//   - Increments remaining output amount by amountOut
//   - Increments calculated amount by (amountIn + feeAmount)
func updateAmounts(step StepComputations, state SwapState, exactInput bool) SwapState {
	amountInWithFee := i256.FromUint256(new(u256.Uint).Add(step.amountIn, step.feeAmount))
	if exactInput {
		state.amountSpecifiedRemaining = i256.Zero().Sub(state.amountSpecifiedRemaining, amountInWithFee)
		state.amountCalculated = i256.Zero().Sub(state.amountCalculated, i256.FromUint256(step.amountOut))
		return state
	}
	state.amountSpecifiedRemaining = i256.Zero().Add(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
	state.amountCalculated = i256.Zero().Add(state.amountCalculated, amountInWithFee)

	return state
}

// tickTransition handles the transition between price ticks during a swap
func tickTransition(step StepComputations, zeroForOne bool, state SwapState, pool *Pool) SwapState {
	// ensure existing state to keep immutability
	newState := state

	if step.initialized {
		var fee0, fee1 *u256.Uint

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
	}

	if zeroForOne {
		newState.tick = step.tickNext - 1
	} else {
		newState.tick = step.tickNext
	}

	return newState
}

func (pool *Pool) swapTransfers(zeroForOne bool, payer, recipient std.Address, amount0, amount1 *i256.Int) {
	var targetTokenPath string
	var amount *i256.Int

	if zeroForOne {
		targetTokenPath = pool.token0Path
		amount = amount0
	} else {
		targetTokenPath = pool.token1Path
		amount = amount1
	}

	// payer -> POOL -> recipient
	pool.transferFromAndVerify(payer, consts.POOL_ADDR, targetTokenPath, amount.Abs(), zeroForOne)
	pool.transferAndVerify(recipient, targetTokenPath, amount, !zeroForOne)
}

// SetFeeProtocolByAdmin sets the fee protocol for all pools
// Also it will be applied to new created pools
func SetFeeProtocolByAdmin(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	newFee := setFeeProtocol(feeProtocol0, feeProtocol1)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetFeeProtocolByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"feeProtocol0", ufmt.Sprintf("%d", feeProtocol0),
		"feeProtocol1", ufmt.Sprintf("%d", feeProtocol1),
		"internal_newFee", ufmt.Sprintf("%d", newFee),
	)
}

// SetFeeProtocol sets the fee protocol for all pools
// Only governance contract can execute this function via proposal
// Also it will be applied to new created pools
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#setfeeprotocol
func SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	newFee := setFeeProtocol(feeProtocol0, feeProtocol1)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetFeeProtocol",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"feeProtocol0", ufmt.Sprintf("%d", feeProtocol0),
		"feeProtocol1", ufmt.Sprintf("%d", feeProtocol1),
		"internal_newFee", ufmt.Sprintf("%d", newFee),
	)
}

func setFeeProtocol(feeProtocol0, feeProtocol1 uint8) uint8 {
	common.IsHalted()

	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		panic(addDetailToError(
			err,
			ufmt.Sprintf("pool.gno__setFeeProtocol() || expected (feeProtocol0(%d) == 0 || (feeProtocol0(%d) >= 4 && feeProtocol0(%d) <= 10)) && (feeProtocol1(%d) == 0 || (feeProtocol1(%d) >= 4 && feeProtocol1(%d) <= 10))", feeProtocol0, feeProtocol0, feeProtocol0, feeProtocol1, feeProtocol1, feeProtocol1),
		))
	}

	newFee := feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )

	// iterate all pool
	for _, pool := range pools {
		pool.slot0.feeProtocol = newFee
	}

	// update slot0
	slot0FeeProtocol = newFee

	return newFee
}

func validateFeeProtocol(feeProtocol0, feeProtocol1 uint8) error {
	if !isValidFeeProtocolValue(feeProtocol0) || !isValidFeeProtocolValue(feeProtocol1) {
		return errInvalidProtocolFeePct
	}
	return nil
}

func isValidFeeProtocolValue(value uint8) bool {
	return value == 0 || (value >= 4 && value <= 10)
}

// CollectProtocolByAdmin collects protocol fees for the given pool that accumulated while it was being used for swap
// Returns collected amount0, amount1 in string
func CollectProtocolByAdmin(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CollectProtocolByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", ufmt.Sprintf("%d", fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

// CollectProtocol collects protocol fees for the given pool that accumulated while it was being used for swap
// Only governance contract can execute this function via proposal
// Returns collected amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#collectprotocol
func CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CollectProtocol",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", ufmt.Sprintf("%d", fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

func collectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	common.IsHalted()

	pool := GetPool(token0Path, token1Path, fee)

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount1Req := u256.MustFromDecimal(amount1Requested)

	amount0 := u256Min(amount0Req, pool.protocolFees.token0)
	amount1 := u256Min(amount1Req, pool.protocolFees.token1)

	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)
	uAmount0 := amount0.Uint64()
	uAmount1 := amount1.Uint64()

	token0 := common.GetToken(pool.token0Path)
	checkTransferError(token0.Transfer(recipient, uAmount0))

	token1 := common.GetToken(pool.token1Path)
	checkTransferError(token1.Transfer(recipient, uAmount1))

	return amount0.ToString(), amount1.ToString()
}

func (pool *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	cond01 := amount0.Gt(u256.Zero())
	cond02 := amount0.Eq(pool.protocolFees.token0)
	if cond01 && cond02 {
		amount0 = new(u256.Uint).Sub(amount0, u256.One())
	}

	cond11 := amount1.Gt(u256.Zero())
	cond12 := amount1.Eq(pool.protocolFees.token1)
	if cond11 && cond12 {
		amount1 = new(u256.Uint).Sub(amount1, u256.One())
	}

	pool.protocolFees.token0 = new(u256.Uint).Sub(pool.protocolFees.token0, amount0)
	pool.protocolFees.token1 = new(u256.Uint).Sub(pool.protocolFees.token1, amount1)

	// return rest fee
	return amount0, amount1
}

func (pool *Pool) transferAndVerify(
	to std.Address,
	tokenPath string,
	amount *i256.Int,
	isToken0 bool,
) {
	if amount.Sign() != -1 {
		panic(addDetailToError(
			errMustBeNegative,
			ufmt.Sprintf("pool.gno__transferAndVerify() || amount(%s) must be negative", amount.ToString()),
		))
	}

	absAmount := amount.Abs()

	token0 := pool.balances.token0
	token1 := pool.balances.token1

	if err := validatePoolBalance(token0, token1, absAmount, isToken0); err != nil {
		panic(err)
	}
	amountUint64, err := checkAmountRange(absAmount)
	if err != nil {
		panic(err)
	}

	transferByRegisterCall(tokenPath, to, amountUint64)

	newBalance, err := updatePoolBalance(token0, token1, absAmount, isToken0)
	if err != nil {
		panic(err)
	}

	if isToken0 {
		pool.balances.token0 = newBalance
	} else {
		pool.balances.token1 = newBalance
	}
}

func validatePoolBalance(token0, token1, amount *u256.Uint, isToken0 bool) error {
	if isToken0 {
		if token0.Lt(amount) {
			return ufmt.Errorf(
				"%s || token0(%s) >= amount(%s)",
				errTransferFailed.Error(), token0.ToString(), amount.ToString(),
			)
		}
		return nil
	}
	if token1.Lt(amount) {
		return ufmt.Errorf(
			"%s || token1(%s) >= amount(%s)",
			errTransferFailed.Error(), token1.ToString(), amount.ToString(),
		)
	}
	return nil
}

func updatePoolBalance(
	token0, token1, amount *u256.Uint,
	isToken0 bool,
) (*u256.Uint, error) {
	var overflow bool
	var newBalance *u256.Uint

	if isToken0 {
		newBalance, overflow = new(u256.Uint).SubOverflow(token0, amount)
		if isBalanceOverflowOrNegative(overflow, newBalance) {
			return nil, ufmt.Errorf(
				"%s || cannot decrease, token0(%s) - amount(%s)",
				errTransferFailed.Error(), token0.ToString(), amount.ToString(),
			)
		}
		return newBalance, nil
	}

	newBalance, overflow = new(u256.Uint).SubOverflow(token1, amount)
	if isBalanceOverflowOrNegative(overflow, newBalance) {
		return nil, ufmt.Errorf(
			"%s || cannot decrease, token1(%s) - amount(%s)",
			errTransferFailed.Error(), token1.ToString(), amount.ToString(),
		)
	}
	return newBalance, nil
}

func isBalanceOverflowOrNegative(overflow bool, newBalance *u256.Uint) bool {
	return overflow || newBalance.Lt(u256.Zero())
}

func (pool *Pool) transferFromAndVerify(
	from, to std.Address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	absAmount := amount
	amountUint64, err := checkAmountRange(absAmount)
	if err != nil {
		panic(err)
	}

	token := common.GetToken(tokenPath)
	checkTransferError(token.TransferFrom(from, to, amountUint64))

	// update pool balances
	if isToken0 {
		pool.balances.token0 = new(u256.Uint).Add(pool.balances.token0, absAmount)
	} else {
		pool.balances.token1 = new(u256.Uint).Add(pool.balances.token1, absAmount)
	}
}

func checkAmountRange(amount *u256.Uint) (uint64, error) {
	res, overflow := amount.Uint64WithOverflow()
	if overflow {
		return 0, ufmt.Errorf(
			"%s || amount(%s) overflows uint64 range",
			errOutOfRange.Error(), amount.ToString(),
		)
	}

	return res, nil
}

// receiver getters
func (p *Pool) PoolGetToken0Path() string {
	return p.token0Path
}

func (p *Pool) PoolGetToken1Path() string {
	return p.token1Path
}

func (p *Pool) PoolGetFee() uint32 {
	return p.fee
}

func (p *Pool) PoolGetBalanceToken0() *u256.Uint {
	return p.balances.token0
}

func (p *Pool) PoolGetBalanceToken1() *u256.Uint {
	return p.balances.token1
}

func (p *Pool) PoolGetTickSpacing() int32 {
	return p.tickSpacing
}

func (p *Pool) PoolGetMaxLiquidityPerTick() *u256.Uint {
	return p.maxLiquidityPerTick
}

func (p *Pool) PoolGetSlot0() Slot0 {
	return p.slot0
}

func (p *Pool) PoolGetSlot0SqrtPriceX96() *u256.Uint {
	return p.slot0.sqrtPriceX96
}

func (p *Pool) PoolGetSlot0Tick() int32 {
	return p.slot0.tick
}

func (p *Pool) PoolGetSlot0FeeProtocol() uint8 {
	return p.slot0.feeProtocol
}

func (p *Pool) PoolGetSlot0Unlocked() bool {
	return p.slot0.unlocked
}

func (p *Pool) PoolGetFeeGrowthGlobal0X128() *u256.Uint {
	return p.feeGrowthGlobal0X128
}

func (p *Pool) PoolGetFeeGrowthGlobal1X128() *u256.Uint {
	return p.feeGrowthGlobal1X128
}

func (p *Pool) PoolGetProtocolFeesToken0() *u256.Uint {
	return p.protocolFees.token0
}

func (p *Pool) PoolGetProtocolFeesToken1() *u256.Uint {
	return p.protocolFees.token1
}

func (p *Pool) PoolGetLiquidity() *u256.Uint {
	return p.liquidity
}

func mustGetPool(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(errDataNotFound,
			ufmt.Sprintf("poolPath(%s) does not exist", poolPath)))
	}
	return pool
}
