package v1

import (
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// decreaseLiquidity reduces position liquidity and collects fees.
// If unwrapResult is true, unwraps WUGNOT to GNOT.
// Returns positionId, liquidity, fee0, fee1, amount0, amount1, poolPath.
func (p *positionV1) decreaseLiquidity(params DecreaseLiquidityParams) (uint64, string, string, string, string, string, string, error) {
	caller := params.caller

	// before decrease liquidity, collect fee first
	_, fee0Str, fee1Str, _, _, _ := p.collectFee(params.positionId, params.unwrapResult, params.caller)

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

	liquidityToRemove := u256.MustFromDecimal(params.liquidity)
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

	positionKey := computePositionKey(position.TickLower(), position.TickUpper())
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	calculatedToken0Balance, calculatedToken1Balance := calculatePositionBalances(position)

	// Add only burned amounts to tokensOwed since fees were already collected and processed in collectFee
	tokensOwed0 := u256.Zero().Add(position.TokensOwed0(), burnedAmount0)
	tokensOwed1 := u256.Zero().Add(position.TokensOwed1(), burnedAmount1)

	newLiquidity, underflow := u256.Zero().SubOverflow(position.Liquidity(), liquidityToRemove)
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "positionLiquidity - liquidityToRemove underflow"))
	}

	newToken0Balance, underflow := u256.Zero().SubOverflow(calculatedToken0Balance, burnedAmount0)
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "calculatedToken0Balance - burnedAmount0 underflow"))
	}

	newToken1Balance, underflow := u256.Zero().SubOverflow(calculatedToken1Balance, burnedAmount1)
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "calculatedToken1Balance - burnedAmount1 underflow"))
	}

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

	if isWrappedToken(pToken0) && params.unwrapResult {
		p.unwrapWithTransferFrom(poolAddr, caller, safeConvertToInt64(collectAmount0))
	} else {
		common.SafeGRC20TransferFrom(cross, pToken0, poolAddr, caller, safeConvertToInt64(collectAmount0))
	}

	if isWrappedToken(pToken1) && params.unwrapResult {
		p.unwrapWithTransferFrom(poolAddr, caller, safeConvertToInt64(collectAmount1))
	} else {
		common.SafeGRC20TransferFrom(cross, pToken1, poolAddr, caller, safeConvertToInt64(collectAmount1))
	}

	// Check for underflow when subtracting collected amounts from tokens owed
	newOwed0, underflow0 := u256.Zero().SubOverflow(position.TokensOwed0(), collectAmount0)
	if underflow0 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed0(%s) < collectAmount0(%s)", position.TokensOwed0().ToString(), collectAmount0.ToString()))
	}
	position.SetTokensOwed0(newOwed0)

	newOwed1, underflow1 := u256.Zero().SubOverflow(position.TokensOwed1(), collectAmount1)
	if underflow1 {
		panic(ufmt.Sprintf("[POSITION] burn.gno | collect() | tokensOwed1(%s) < collectAmount1(%s)", position.TokensOwed1().ToString(), collectAmount1.ToString()))
	}
	position.SetTokensOwed1(newOwed1)

	if position.IsClear() {
		position.SetBurned(true) // just update flag (we don't want to burn actual position)
	}

	p.mustUpdatePosition(params.positionId, *position)

	return params.positionId, liquidityToRemove.ToString(), fee0Str, fee1Str, collect0, collect1, position.PoolKey(), nil
}

// calculateFees calculates the fees for the current position.
func (p *positionV1) calculateFees(position *position.Position, currentFeeGrowth FeeGrowthInside) (*u256.Uint, *u256.Uint) {
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

	tokensOwed0, overflow0 := u256.Zero().AddOverflow(u256.Zero().Set(position.TokensOwed0()), fee0)
	if overflow0 {
		panic(newErrorWithDetail(errOverflow, "tokensOwed0 + fee0 overflow"))
	}

	tokensOwed1, overflow1 := u256.Zero().AddOverflow(u256.Zero().Set(position.TokensOwed1()), fee1)
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
	diff, underflow := u256.Zero().SubOverflow(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128)
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "feeGrowthInsideLastX128 - positionFeeGrowthInsideLastX128 underflow"))
	}
	return u256.MulDiv(diff, positionLiquidity, q128)
}
