package position

import (
	"gno.land/p/nt/ufmt"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"
)

// decreaseLiquidity reduces position liquidity and collects fees.
// If unwrapResult is true, unwraps WUGNOT to GNOT.
// Returns positionId, liquidity, fee0, fee1, amount0, amount1, poolPath.
func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, string, string, string, string, string, string, error) {
	caller := params.caller

	// before decrease liquidity, collect fee first
	_, fee0Str, fee1Str, _, _, _ := collectFee(params.positionId, params.unwrapResult, params.caller)

	position := MustGetPosition(params.positionId)
	positionLiquidity := position.liquidity
	if positionLiquidity.IsZero() {
		return params.positionId,
			"",
			fee0Str,
			fee1Str,
			"", "",
			position.poolKey,
			makeErrorWithDetails(
				errZeroLiquidity,
				ufmt.Sprintf("position(position ID:%d) has 0 liquidity", params.positionId),
			)
	}

	liquidityToRemove := u256.MustFromDecimal(params.liquidity)
	if liquidityToRemove.Gt(positionLiquidity) {
		return params.positionId,
			liquidityToRemove.ToString(),
			fee0Str,
			fee1Str,
			"", "",
			position.poolKey,
			makeErrorWithDetails(
				errInvalidLiquidity,
				ufmt.Sprintf("Liquidity requested(%s) is greater than liquidity held(%s)", liquidityToRemove.ToString(), positionLiquidity.ToString()),
			)
	}

	pToken0, pToken1, pFee := splitOf(position.poolKey)
	burn0, burn1 := pl.Burn(cross, pToken0, pToken1, pFee, position.tickLower, position.tickUpper, liquidityToRemove.ToString(), caller)

	burnedAmount0 := u256.MustFromDecimal(burn0)
	burnedAmount1 := u256.MustFromDecimal(burn1)
	if isSlippageExceeded(burnedAmount0, burnedAmount1, params.amount0Min, params.amount1Min) {
		return params.positionId,
			liquidityToRemove.ToString(),
			fee0Str,
			fee1Str,
			burn0,
			burn1,
			position.poolKey,
			makeErrorWithDetails(
				errSlippage,
				ufmt.Sprintf("burnedAmount0(%s) >= amount0Min(%s) || burnedAmount1(%s) >= amount1Min(%s)",
					burnedAmount0.ToString(),
					params.amount0Min.ToString(),
					burnedAmount1.ToString(),
					params.amount1Min.ToString(),
				),
			)
	}

	positionKey := computePositionKey(position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.poolKey, positionKey)

	currentSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(position.poolKey)
	lowerTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickUpper)
	calculatedToken0BalanceStr, calculatedToken1BalanceStr := common.GetAmountsForLiquidity(
		currentSqrtPriceX96,
		lowerTickSqrtPriceX96,
		upperTickSqrtPriceX96,
		position.liquidity,
	)
	calculatedToken0Balance := u256.MustFromDecimal(calculatedToken0BalanceStr)
	calculatedToken1Balance := u256.MustFromDecimal(calculatedToken1BalanceStr)

	position.tokensOwed0 = updateTokensOwed(
		feeGrowthInside0LastX128,
		position.feeGrowthInside0LastX128,
		position.liquidity,
		burnedAmount0,
		position.tokensOwed0,
	)

	position.tokensOwed1 = updateTokensOwed(
		feeGrowthInside1LastX128,
		position.feeGrowthInside1LastX128,
		position.liquidity,
		burnedAmount1,
		position.tokensOwed1,
	)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = u256.Zero().Sub(positionLiquidity, liquidityToRemove)
	position.token0Balance = u256.Zero().Sub(calculatedToken0Balance, burnedAmount0)
	position.token1Balance = u256.Zero().Sub(calculatedToken1Balance, burnedAmount1)
	mustUpdatePosition(params.positionId, position)

	collect0, collect1 := pl.Collect(
		cross,
		pToken0,
		pToken1,
		pFee,
		caller,
		position.tickLower,
		position.tickUpper,
		burn0,
		burn1,
	)

	collectAmount0 := u256.MustFromDecimal(collect0)
	collectAmount1 := u256.MustFromDecimal(collect1)

	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	if isWrappedToken(pToken0) && params.unwrapResult {
		unwrapWithTransferFrom(poolAddr, caller, safeConvertToInt64(collectAmount0))
	} else {
		common.TransferFrom(cross, pToken0, poolAddr, caller, safeConvertToInt64(collectAmount0))
	}

	if isWrappedToken(pToken1) && params.unwrapResult {
		unwrapWithTransferFrom(poolAddr, caller, safeConvertToInt64(collectAmount1))
	} else {
		common.TransferFrom(cross, pToken1, poolAddr, caller, safeConvertToInt64(collectAmount1))
	}

	// Check for underflow when subtracting collected amounts from tokens owed
	newOwed0, underflow0 := u256.Zero().SubOverflow(position.tokensOwed0, collectAmount0)
	if underflow0 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed0(%s) < collectAmount0(%s)", position.tokensOwed0.ToString(), collectAmount0.ToString()))
	}
	position.tokensOwed0 = newOwed0

	newOwed1, underflow1 := u256.Zero().SubOverflow(position.tokensOwed1, collectAmount1)
	if underflow1 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed1(%s) < collectAmount1(%s)", position.tokensOwed1.ToString(), collectAmount1.ToString()))
	}
	position.tokensOwed1 = newOwed1

	if position.isClear() {
		position.burned = true // just update flag (we don't want to burn actual position)
	}

	mustUpdatePosition(params.positionId, position)

	return params.positionId, liquidityToRemove.ToString(), fee0Str, fee1Str, collect0, collect1, position.poolKey, nil
}

func updateTokensOwed(
	feeGrowthInsideLastX128 *u256.Uint,
	positionFeeGrowthInsideLastX128 *u256.Uint,
	positionLiquidity *u256.Uint,
	burnedAmount *u256.Uint,
	tokensOwed *u256.Uint,
) *u256.Uint {
	additionalTokensOwed := calculateTokensOwed(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128, positionLiquidity)
	add := u256.Zero().Add(burnedAmount, additionalTokensOwed)
	return u256.Zero().Add(tokensOwed, add)
}

// calculateFees calculates the fees for the current position.
func calculateFees(position Position, currentFeeGrowth FeeGrowthInside) (*u256.Uint, *u256.Uint) {
	fee0 := calculateTokensOwed(
		currentFeeGrowth.feeGrowthInside0LastX128,
		position.feeGrowthInside0LastX128,
		position.liquidity,
	)

	fee1 := calculateTokensOwed(
		currentFeeGrowth.feeGrowthInside1LastX128,
		position.feeGrowthInside1LastX128,
		position.liquidity,
	)

	tokensOwed0, overflow0 := u256.Zero().AddOverflow(u256.Zero().Set(position.tokensOwed0), fee0)
	if overflow0 {
		panic(newErrorWithDetail(errOverflow, "tokensOwed0 + fee0 overflow"))
	}
	tokensOwed1, overflow1 := u256.Zero().AddOverflow(u256.Zero().Set(position.tokensOwed1), fee1)
	if overflow1 {
		panic(newErrorWithDetail(errOverflow, "tokensOwed1 + fee1 overflow"))
	}

	return tokensOwed0, tokensOwed1
}

func calculateTokensOwed(
	feeGrowthInsideLastX128 *u256.Uint,
	positionFeeGrowthInsideLastX128 *u256.Uint,
	positionLiquidity *u256.Uint,
) *u256.Uint {
	diff := u256.Zero().Sub(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128)
	// TODO: make Q128 a global variable
	return u256.MulDiv(diff, positionLiquidity, u256.MustFromDecimal(Q128))
}
