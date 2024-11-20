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
	_liquidityAmount string, // uint128
	positionCaller std.Address,
) (string, string) { // uint256 x2
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if caller != consts.POSITION_ADDR {
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
	_, amount0, amount1 := pool.modifyPosition(
		ModifyPositionParams{
			recipient,                         // owner
			tickLower,                         // tickLower
			tickUpper,                         // tickUpper
			i256.FromUint256(liquidityAmount), // liquidityDelta
		},
	)

	if amount0.Gt(i256.Zero()) {
		pool.transferFromAndVerify(positionCaller, consts.POOL_ADDR, pool.token0Path, amount0, true)
	}

	if amount1.Gt(i256.Zero()) {
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
	_liquidityAmount string, // uint128
) (string, string) { // uint256 x2
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if common.GetLimitCaller() {
		if caller != consts.POSITION_ADDR {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Burn() || only position(%s) can call pool burn(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)

	pool := GetPool(token0Path, token1Path, fee)

	position, amount0Int, amount1Int := pool.modifyPosition( // in256 x2
		ModifyPositionParams{
			caller, // msg.sender
			tickLower,
			tickUpper,
			i256.Zero().Neg(i256.FromUint256(liquidityAmount)),
		},
	)

	amount0 := amount0Int.Abs()
	amount1 := amount1Int.Abs()

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
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if caller != consts.POSITION_ADDR {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Collect() || only position(%s) can call pool collect(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	amount0Requested := u256.MustFromDecimal(_amount0Requested)
	amount1Requested := u256.MustFromDecimal(_amount1Requested)

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool.gno__Collect() || positionKey(%s) does not exist", positionKey),
		))
	}

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0 := u256Min(amount0Requested, position.tokensOwed0)
	amount0 = u256Min(amount0, pool.balances.token0)

	// Update state first then transfer
	position.tokensOwed0 = new(u256.Uint).Sub(position.tokensOwed0, amount0)
	pool.balances.token0 = new(u256.Uint).Sub(pool.balances.token0, amount0)
	transferByRegisterCall(pool.token0Path, recipient, amount0.Uint64())

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1 := u256Min(amount1Requested, position.tokensOwed1)
	amount1 = u256Min(amount1, pool.balances.token1)

	// Update state first then transfer
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1)
	pool.balances.token1 = new(u256.Uint).Sub(pool.balances.token1, amount1)
	transferByRegisterCall(pool.token1Path, recipient, amount1.Uint64())

	pool.positions[positionKey] = position

	return amount0.ToString(), amount1.ToString()
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
	_amountSpecified string, // int256
	_sqrtPriceLimitX96 string, // uint160
	payer std.Address, // router
) (string, string) { // int256 x2
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if caller != consts.ROUTER_ADDR {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Swap() || only router(%s) can call pool swap(), called from %s", consts.ROUTER_ADDR, caller.String()),
			))
		}
	}

	if _amountSpecified == "0" {
		panic(addDetailToError(
			errInvalidSwapAmount,
			ufmt.Sprintf("pool.gno__Swap() || amountSpecified == 0"),
		))
	}

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	sqrtPriceLimitX96 := u256.MustFromDecimal(_sqrtPriceLimitX96)

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0

	if !(slot0Start.unlocked) {
		panic(addDetailToError(
			errLockedPool,
			ufmt.Sprintf("pool.gno__Swap() || slot0Start.unlocked(false) must be unlocked)"),
		))
	}

	var feeProtocol uint8
	var feeGrowthGlobalX128 *u256.Uint

	if zeroForOne {
		minSqrtRatio := u256.MustFromDecimal(consts.MIN_SQRT_RATIO)

		cond1 := sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Gt(minSqrtRatio)
		if !(cond1 && cond2) {
			panic(addDetailToError(
				errPriceOutOfRange,
				ufmt.Sprintf("pool.gno__Swap() || sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > consts.MIN_SQRT_RATIO(%s)", sqrtPriceLimitX96.ToString(), slot0Start.sqrtPriceX96.ToString(), sqrtPriceLimitX96.ToString(), consts.MIN_SQRT_RATIO),
			))
		}
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128

	} else {
		maxSqrtRatio := u256.MustFromDecimal(consts.MAX_SQRT_RATIO)

		cond1 := sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Lt(maxSqrtRatio)
		if !(cond1 && cond2) {
			panic(addDetailToError(
				errPriceOutOfRange,
				ufmt.Sprintf("pool.gno__Swap() || sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < consts.MAX_SQRT_RATIO(%s)", sqrtPriceLimitX96.ToString(), slot0Start.sqrtPriceX96.ToString(), sqrtPriceLimitX96.ToString(), consts.MAX_SQRT_RATIO),
			))
		}

		feeProtocol = slot0Start.feeProtocol / 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal1X128
	}

	pool.slot0.unlocked = false
	cache := newSwapCache(feeProtocol, pool.liquidity)
	state := pool.newSwapState(amountSpecified, feeGrowthGlobalX128, cache.liquidityStart)

	exactInput := amountSpecified.Gt(i256.Zero())

	// continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
	swapFee := u256.Zero()
	for !(state.amountSpecifiedRemaining.IsZero()) && !(state.sqrtPriceX96.Eq(sqrtPriceLimitX96)) {
		var step StepComputations
		step.sqrtPriceStartX96 = state.sqrtPriceX96

		step.tickNext, step.initialized = pool.tickBitmapNextInitializedTickWithInOneWord(
			state.tick,
			pool.tickSpacing,
			zeroForOne,
		)

		// ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
		if step.tickNext < consts.MIN_TICK {
			step.tickNext = consts.MIN_TICK
		} else if step.tickNext > consts.MAX_TICK {
			step.tickNext = consts.MAX_TICK
		}

		// get the price for the next tick
		step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)

		isLower := step.sqrtPriceNextX96.Lt(sqrtPriceLimitX96)
		isHigher := step.sqrtPriceNextX96.Gt(sqrtPriceLimitX96)

		var sqrtRatioTargetX96 *u256.Uint
		if (zeroForOne && isLower) || (!zeroForOne && isHigher) {
			sqrtRatioTargetX96 = sqrtPriceLimitX96
		} else {
			sqrtRatioTargetX96 = step.sqrtPriceNextX96
		}

		_sqrtPriceX96Str, _amountInStr, _amountOutStr, _feeAmountStr := plp.SwapMathComputeSwapStepStr(
			state.sqrtPriceX96,
			sqrtRatioTargetX96,
			state.liquidity,
			state.amountSpecifiedRemaining,
			uint64(pool.fee),
		)
		state.sqrtPriceX96 = u256.MustFromDecimal(_sqrtPriceX96Str)
		step.amountIn = u256.MustFromDecimal(_amountInStr)
		step.amountOut = u256.MustFromDecimal(_amountOutStr)
		step.feeAmount = u256.MustFromDecimal(_feeAmountStr)

		amountInWithFee := i256.FromUint256(new(u256.Uint).Add(step.amountIn, step.feeAmount))
		if exactInput {
			state.amountSpecifiedRemaining = i256.Zero().Sub(state.amountSpecifiedRemaining, amountInWithFee)
			state.amountCalculated = i256.Zero().Sub(state.amountCalculated, i256.FromUint256(step.amountOut))
		} else {
			state.amountSpecifiedRemaining = i256.Zero().Add(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
			state.amountCalculated = i256.Zero().Add(state.amountCalculated, amountInWithFee)
		}

		// if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
		if cache.feeProtocol > 0 {
			delta := new(u256.Uint).Div(step.feeAmount, u256.NewUint(uint64(cache.feeProtocol)))
			step.feeAmount = new(u256.Uint).Sub(step.feeAmount, delta)
			state.protocolFee = new(u256.Uint).Add(state.protocolFee, delta)
		}

		// update global fee tracker
		if state.liquidity.Gt(u256.Zero()) {
			update := u256.MulDiv(step.feeAmount, u256.MustFromDecimal(consts.Q128), state.liquidity)
			state.feeGrowthGlobalX128 = new(u256.Uint).Add(state.feeGrowthGlobalX128, update)
		}
		swapFee = new(u256.Uint).Add(swapFee, step.feeAmount)

		// shift tick if we reached the next price
		if state.sqrtPriceX96.Eq(step.sqrtPriceNextX96) {
			// if the tick is initialized, run the tick transition
			if step.initialized {
				var fee0, fee1 *u256.Uint

				// check for the placeholder value, which we replace with the actual value the first time the swap crosses an initialized tick
				if zeroForOne {
					fee0 = state.feeGrowthGlobalX128
					fee1 = pool.feeGrowthGlobal1X128
				} else {
					fee0 = pool.feeGrowthGlobal0X128
					fee1 = state.feeGrowthGlobalX128
				}

				liquidityNet := pool.tickCross(
					step.tickNext,
					fee0,
					fee1,
				)

				// if we're moving leftward, we interpret liquidityNet as the opposite sign
				if zeroForOne {
					liquidityNet = i256.Zero().Neg(liquidityNet)
				}

				state.liquidity = liquidityMathAddDelta(state.liquidity, liquidityNet)
			}

			if zeroForOne {
				state.tick = step.tickNext - 1
			} else {
				state.tick = step.tickNext
			}
		} else if !(state.sqrtPriceX96.Eq(step.sqrtPriceStartX96)) {
			// recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
			state.tick = common.TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
		}
	}
	// END LOOP

	// update pool sqrtPrice
	pool.slot0.sqrtPriceX96 = state.sqrtPriceX96

	// update tick if it changed
	if state.tick != slot0Start.tick {
		pool.slot0.tick = state.tick
	}

	// update liquidity if it changed
	if !(cache.liquidityStart.Eq(state.liquidity)) {
		pool.liquidity = state.liquidity
	}

	// update fee growth global and, if necessary, protocol fees
	// overflow is acceptable, protocol has to withdraw before it hits MAX_UINT256 fees
	if zeroForOne {
		pool.feeGrowthGlobal0X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token0 = new(u256.Uint).Add(pool.protocolFees.token0, state.protocolFee)
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token1 = new(u256.Uint).Add(pool.protocolFees.token1, state.protocolFee)
		}
	}

	var amount0, amount1 *i256.Int
	if zeroForOne == exactInput {
		amount0 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
	}

	// actual swap
	if zeroForOne {
		// payer > POOL
		pool.transferFromAndVerify(payer, consts.POOL_ADDR, pool.token0Path, amount0, true)

		// POOL > recipient
		pool.transferAndVerify(recipient, pool.token1Path, amount1, false)

	} else {
		// payer > POOL
		pool.transferFromAndVerify(payer, consts.POOL_ADDR, pool.token1Path, amount1, false)

		// POOL > recipient
		pool.transferAndVerify(recipient, pool.token0Path, amount0, true)

	}

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"Swap",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", GetPoolPath(token0Path, token1Path, fee),
		"zeroForOne", ufmt.Sprintf("%t", zeroForOne),
		"amountSpecified", _amountSpecified,
		"sqrtPriceLimitX96", _sqrtPriceLimitX96,
		"payer", payer.String(),
		"recipient", recipient.String(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_protocolFee0", pool.protocolFees.token0.ToString(),
		"internal_protocolFee1", pool.protocolFees.token1.ToString(),
		"internal_swapFee", swapFee.ToString(),
		"internal_sqrtPriceX96", pool.slot0.sqrtPriceX96.ToString(),
	)

	pool.slot0.unlocked = true
	return amount0.ToString(), amount1.ToString()
}

// SetFeeProtocolByAdmin sets the fee protocol for all pools
// Also it will be applied to new created pools
func SetFeeProtocolByAdmin(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"pool.gno__SetFeeProtocolByAdmin() || only admin(%s) can set fee protocol, called from %s",
				consts.ADMIN,
				caller,
			),
		))
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
func SetFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"pool.gno__SetFeeProtocol() || only governance(%s) can set fee protocol, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
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

func setFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) uint8 {
	common.IsHalted()

	fee0Cond := feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)
	fee1Cond := feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)
	if !(fee0Cond && fee1Cond) {
		panic(addDetailToError(
			errInvalidPotocolFeePct,
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

// CollectProtocolByAdmin collects protocol fees for the given pool that accumulated while it was being used for swap
// Returns collected amount0, amount1 in string
func CollectProtocolByAdmin(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"pool.gno__CollectProtocolByAdmin() || only admin(%s) can collect protocol fees, called from %s",
				consts.ADMIN,
				caller,
			),
		))
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		_amount0Requested,
		_amount1Requested,
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
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"pool.gno__CollectProtocol() || only governance(%s) can collect protocol fees, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		_amount0Requested,
		_amount1Requested,
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
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.IsHalted()

	amount0Requested := u256.MustFromDecimal(_amount0Requested)
	amount1Requested := u256.MustFromDecimal(_amount1Requested)

	pool := GetPool(token0Path, token1Path, fee)

	amount0 := u256Min(amount0Requested, pool.protocolFees.token0)
	amount1 := u256Min(amount1Requested, pool.protocolFees.token1)

	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)
	uAmount0 := amount0.Uint64()
	uAmount1 := amount1.Uint64()

	transferByRegisterCall(pool.token0Path, recipient, uAmount0)
	transferByRegisterCall(pool.token1Path, recipient, uAmount1)

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
	if amount.IsZero() {
		return
	}

	// must be negative to send token from pool to user
	// as point of view from pool, it is negative
	if !amount.IsNeg() {
		panic(addDetailToError(
			errMustBeNegative,
			ufmt.Sprintf("pool.gno__transferAndVerify() || amount(%s) must be negative", amount.ToString()),
		))
	}

	// check pool.balances
	if isToken0 {
		if pool.balances.token0.Lt(amount.Abs()) {
			panic(addDetailToError(
				errTransferFailed,
				ufmt.Sprintf("pool.gno__transferAndVerify() || pool.balances.token0(%s) >= amount.Abs(%s)", pool.balances.token0.ToString(), amount.Abs().ToString()),
			))
		}
	} else {
		if pool.balances.token1.Lt(amount.Abs()) {
			panic(addDetailToError(
				errTransferFailed,
				ufmt.Sprintf("pool.gno__transferAndVerify() || pool.balances.token1(%s) >= amount.Abs(%s)", pool.balances.token1.ToString(), amount.Abs().ToString()),
			))
		}
	}

	amountUint64 := checkAmountRange(amount)

	// try sending
	// will panic if following conditions are met:
	// - POOL does not have enough balance
	// - token is not registered
	transferByRegisterCall(tokenPath, to, amountUint64)

	// update pool.balances
	var overflow bool
	if isToken0 {
		pool.balances.token0, overflow = new(u256.Uint).SubOverflow(pool.balances.token0, amount.Abs())
		if overflow {
			panic(addDetailToError(
				errTransferFailed,
				ufmt.Sprintf("pool.gno__transferAndVerify() || cannot decrease, pool.balances.token0(%s) - amount(%s)", pool.balances.token0.ToString(), amount.Abs().ToString()),
			))
		}
	} else {
		pool.balances.token1, overflow = new(u256.Uint).SubOverflow(pool.balances.token1, amount.Abs())
		if pool.balances.token1.Lt(u256.Zero()) {
			panic(addDetailToError(
				errTransferFailed,
				ufmt.Sprintf("pool.gno__transferAndVerify() || cannot decrease, pool.balances.token1(%s) - amount(%s)", pool.balances.token1.ToString(), amount.Abs().ToString()),
			))
		}
	}
}

func (pool *Pool) transferFromAndVerify(
	from, to std.Address,
	tokenPath string,
	amount *i256.Int,
	isToken0 bool,
) {
	amountUint64 := checkAmountRange(amount)

	// try sending
	// will panic if following conditions are met:
	// - POOL does not have enough approved amount
	// - from does not have enough balance
	// - token is not registered
	transferFromByRegisterCall(tokenPath, from, to, amountUint64)

	// update pool.balances
	if isToken0 {
		pool.balances.token0 = new(u256.Uint).Add(pool.balances.token0, amount.Abs())
	} else {
		pool.balances.token1 = new(u256.Uint).Add(pool.balances.token1, amount.Abs())
	}
}

func checkAmountRange(amount *i256.Int) uint64 {
	// check amount is in uint64 range
	amountAbs := amount.Abs()
	amountUint64, overflow := amountAbs.Uint64WithOverflow()
	if overflow {
		panic(addDetailToError(
			errOutOfRange,
			ufmt.Sprintf("pool.gno__checkAmountRange() || amountAbs(%s) overflows uint64 range", amountAbs.ToString()),
		))
	}

	return amountUint64
}
