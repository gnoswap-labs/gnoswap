package position

import (
	"chain"

	"gno.land/r/gnoswap/access/v1"

	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt/v1"
)

// Reposition adjusts the price range and liquidity of an existing position.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: current realm context forwarded from the public wrapper; the implementation validates it as current
//   - positionId: NFT token ID to reposition
//   - tickLower: new lower tick boundary of the position's price range
//   - tickUpper: new upper tick boundary of the position's price range
//   - amount0DesiredStr: desired token0 amount for the new position, represented as a decimal string
//   - amount1DesiredStr: desired token1 amount for the new position, represented as a decimal string
//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
//   - deadline: transaction expiration timestamp
//
// Returns:
//   - positionId: NFT token ID that was repositioned
//   - liquidity: new liquidity amount, represented as a decimal string
//   - tickLower: lower tick boundary applied to the position
//   - tickUpper: upper tick boundary applied to the position
//   - amount0: actual token0 amount added to the new range, represented as a decimal string
//   - amount1: actual token1 amount added to the new range, represented as a decimal string
func (p *positionV1) Reposition(
	_ int,
	rlm realm,
	positionId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, int32, int32, string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedPosition()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	assertIsOwnerForToken(p, positionId, caller)
	assertIsNotExpired(deadline)

	emission.MintAndDistributeGns(cross(rlm))

	// The position must be clear (zero liquidity and zero tokens owed) before
	// it can be repositioned.
	position := p.mustGetPosition(positionId)

	token0, token1, _ := splitOf(position.PoolKey())
	common.AssertIsNotHandleNativeCoin()

	oldTickLower := position.TickLower()
	oldTickUpper := position.TickUpper()

	if !position.IsClear() {
		panic(newErrorWithDetail(
			errNotClear,
			ufmt.Sprintf(
				"position(%d) isn't clear(liquidity:%s, tokensOwed0:%d, tokensOwed1:%d)",
				positionId,
				position.Liquidity(),
				position.TokensOwed0(),
				position.TokensOwed1(),
			),
		))
	}

	if err := validateTokenPath(token0, token1); err != nil {
		panic(newErrorWithDetail(err.Error(), ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	poolKey := position.PoolKey()

	liquidity, amount0, amount1 := p.addLiquidity(
		0,
		rlm,
		AddLiquidityParams{
			poolKey:        poolKey,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: u256.MustFromDecimal(amount0DesiredStr),
			amount1Desired: u256.MustFromDecimal(amount1DesiredStr),
			amount0Min:     u256.MustFromDecimal(amount0MinStr),
			amount1Min:     u256.MustFromDecimal(amount1MinStr),
			caller:         caller,
		},
	)

	// update position tickLower, tickUpper to new value
	// because getCurrentFeeGrowth() uses tickLower, tickUpper
	position.SetTickLower(tickLower)
	position.SetTickUpper(tickUpper)

	currentFeeGrowth, err := p.getCurrentFeeGrowth(position, caller)
	if err != nil {
		panic(newErrorWithDetail(err.Error(), "failed to get current fee growth"))
	}
	position.SetFeeGrowthInside0LastX128(currentFeeGrowth.feeGrowthInside0LastX128.ToString())
	position.SetFeeGrowthInside1LastX128(currentFeeGrowth.feeGrowthInside1LastX128.ToString())

	position.SetLiquidity(liquidity.ToString())

	// Do not reset the fee-growth checkpoints: a full decrease followed by
	// repositioning must not create an unintended unclaimed-fee balance.
	position.SetTokensOwed0(0)
	position.SetTokensOwed1(0)
	position.SetBurned(false)
	p.mustUpdatePosition(0, rlm, positionId, *position)

	pool := mustGetPool(poolKey)
	positionLiquidity, err := p.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	tickCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp, err := currentPoolObservation(poolKey)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"Reposition",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", utils.FormatUint(positionId),
		"tickLower", utils.FormatInt(tickLower),
		"tickUpper", utils.FormatInt(tickUpper),
		"liquidityDelta", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"prevTickLower", utils.FormatInt(oldTickLower),
		"prevTickUpper", utils.FormatInt(oldTickUpper),
		"poolPath", poolKey,
		"sqrtPriceX96", pool.Slot0SqrtPriceX96().ToString(),
		"positionLiquidity", positionLiquidity,
		"poolLiquidity", pool.Liquidity().ToString(),
		"token0Balance", utils.FormatInt(pool.BalanceToken0()),
		"token1Balance", utils.FormatInt(pool.BalanceToken1()),
		"tickCumulative", utils.FormatInt(tickCumulative),
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", utils.FormatInt(observationTimestamp),
	)

	return positionId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
}
