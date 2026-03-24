package v1

import (
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// decreaseLiquidity reduces position liquidity and collects fees.
// Returns positionId, liquidity, fee0, fee1, amount0, amount1, poolPath.
func (p *positionV1) decreaseLiquidity(params DecreaseLiquidityParams) (uint64, string, string, string, string, string, string, error) {
	caller := params.caller

	// before decrease liquidity, collect fee first
	_, fee0Str, fee1Str, _, _, _ := p.collectFee(params.positionId, params.caller)

	position := p.mustGetPosition(params.positionId)
	if position.Liquidity().IsZero() {
		return params.positionId,
			"",
			fee0Str,
			fee1Str,
			"", "",
			position.PoolKey(),
			makeErrorWithDetails(
				errZeroLiquidity,
				ufmt.Sprintf("position(position ID:%d) has 0 liquidity", params.positionId),
			)
	}

	liquidityToRemove, err := u256.FromDecimal(params.liquidity)
	if err != nil {
		return params.positionId,
			"",
			fee0Str,
			fee1Str,
			"", "",
			position.PoolKey(),
			makeErrorWithDetails(errInvalidLiquidity, ufmt.Sprintf("liquidity(%s)", params.liquidity))
	}

	if liquidityToRemove.Gt(position.Liquidity()) {
		return params.positionId,
			liquidityToRemove.ToString(),
			fee0Str,
			fee1Str,
			"", "",
			position.PoolKey(),
			makeErrorWithDetails(
				errInvalidLiquidity,
				ufmt.Sprintf("Liquidity requested(%s) is greater than liquidity held(%s)", liquidityToRemove.ToString(), position.Liquidity().ToString()),
			)
	}

	pToken0, pToken1, pFee := splitOf(position.PoolKey())
	burn0, burn1 := pl.Burn(cross, pToken0, pToken1, pFee, position.TickLower(), position.TickUpper(), liquidityToRemove.ToString(), caller)

	burnedAmount0 := u256.MustFromDecimal(burn0)
	burnedAmount1 := u256.MustFromDecimal(burn1)
	burnedAmount0Int64 := safeConvertToInt64(burnedAmount0)
	burnedAmount1Int64 := safeConvertToInt64(burnedAmount1)

	positionKey := computePositionKey(position.TickLower(), position.TickUpper())
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	calculatedToken0Balance, calculatedToken1Balance := calculatePositionBalances(position)

	// Add only burned amounts to tokensOwed since fees were already collected and processed in collectFee
	tokensOwed0 := safeAddInt64(position.TokensOwed0(), burnedAmount0Int64)
	tokensOwed1 := safeAddInt64(position.TokensOwed1(), burnedAmount1Int64)

	newLiquidity, overflow := u256.Zero().SubOverflow(position.Liquidity(), liquidityToRemove)
	if overflow {
		panic(ufmt.Sprintf("[POSITION] burn.gno | liquidity underflow | positionLiquidity(%s) < liquidityToRemove(%s)", position.Liquidity().ToString(), liquidityToRemove.ToString()))
	}
	newToken0Balance := safeSubInt64(calculatedToken0Balance, burnedAmount0Int64)
	newToken1Balance := safeSubInt64(calculatedToken1Balance, burnedAmount1Int64)

	position.SetTokensOwed0(tokensOwed0)
	position.SetTokensOwed1(tokensOwed1)
	position.SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128)
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128)
	position.SetLiquidity(newLiquidity)
	position.SetToken0Balance(newToken0Balance)
	position.SetToken1Balance(newToken1Balance)

	p.mustUpdatePosition(params.positionId, *position)

	collect0, collect1 := pl.Collect(
		cross,
		pToken0,
		pToken1,
		pFee,
		caller,
		position.TickLower(),
		position.TickUpper(),
		burn0,
		burn1,
	)

	collectAmount0 := u256.MustFromDecimal(collect0)
	collectAmount1 := u256.MustFromDecimal(collect1)

	// Slippage check on actually collected amounts to ensure user receives minimum expected tokens
	if isSlippageExceeded(collectAmount0, collectAmount1, params.amount0Min, params.amount1Min) {
		return params.positionId,
			liquidityToRemove.ToString(),
			fee0Str,
			fee1Str,
			collect0,
			collect1,
			position.PoolKey(),
			makeErrorWithDetails(
				errSlippage,
				ufmt.Sprintf("collectAmount0(%s) >= amount0Min(%s) && collectAmount1(%s) >= amount1Min(%s)",
					collectAmount0.ToString(),
					params.amount0Min.ToString(),
					collectAmount1.ToString(),
					params.amount1Min.ToString(),
				),
			)
	}

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())

	common.SafeGRC20TransferFrom(cross, pToken0, poolAddr, caller, safeConvertToInt64(collectAmount0))
	common.SafeGRC20TransferFrom(cross, pToken1, poolAddr, caller, safeConvertToInt64(collectAmount1))

	// Check for underflow when subtracting collected amounts from tokens owed
	collectAmount0Int64 := safeConvertToInt64(collectAmount0)
	collectAmount1Int64 := safeConvertToInt64(collectAmount1)

	if position.TokensOwed0() < collectAmount0Int64 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed0(%d) < collectAmount0(%d)", position.TokensOwed0(), collectAmount0Int64))
	}
	position.SetTokensOwed0(safeSubInt64(position.TokensOwed0(), collectAmount0Int64))

	if position.TokensOwed1() < collectAmount1Int64 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed1(%d) < collectAmount1(%d)", position.TokensOwed1(), collectAmount1Int64))
	}
	position.SetTokensOwed1(safeSubInt64(position.TokensOwed1(), collectAmount1Int64))

	if position.IsClear() {
		position.SetBurned(true) // just update flag (we don't want to burn actual position)
	}

	p.mustUpdatePosition(params.positionId, *position)

	return params.positionId, liquidityToRemove.ToString(), fee0Str, fee1Str, collect0, collect1, position.PoolKey(), nil
}

// calculateFees calculates the fees for the current position.
func (p *positionV1) calculateFees(position *position.Position, currentFeeGrowth FeeGrowthInside) (int64, int64) {
	fee0 := calculateTokensOwed(
		currentFeeGrowth.feeGrowthInside0LastX128,
		position.FeeGrowthInside0LastX128(),
		position.Liquidity(),
	)

	fee1 := calculateTokensOwed(
		currentFeeGrowth.feeGrowthInside1LastX128,
		position.FeeGrowthInside1LastX128(),
		position.Liquidity(),
	)

	return safeAddInt64(position.TokensOwed0(), safeConvertToInt64(fee0)), safeAddInt64(position.TokensOwed1(), safeConvertToInt64(fee1))
}

func calculateTokensOwed(
	feeGrowthInsideLastX128 *u256.Uint,
	positionFeeGrowthInsideLastX128 *u256.Uint,
	positionLiquidity *u256.Uint,
) *u256.Uint {
	diff, underflow := u256.Zero().SubOverflow(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128)
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "feeGrowthInsideLastX128 - positionFeeGrowthInsideLastX128 underflow"))
	}
	return u256.MulDiv(diff, positionLiquidity, q128)
}
