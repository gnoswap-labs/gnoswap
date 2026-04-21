package v1

import (
	"chain"
	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
)

// Reposition adjusts the price range and liquidity of an existing position.
//
// Parameters:
//   - positionId: NFT token ID to reposition
//   - tickLower, tickUpper: new price range boundaries
//   - amount0DesiredStr, amount1DesiredStr: desired token amounts for new position
//   - amount0MinStr, amount1MinStr: minimum acceptable amounts (slippage protection)
//   - deadline: transaction expiration timestamp
//
// Returns positionId, liquidity, tickLower, tickUpper, amount0, amount1.
func (p *positionV1) Reposition(
	positionId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, int32, int32, string, string) {
	halt.AssertIsNotHaltedPosition()
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerForToken(p, positionId, caller)
	assertIsNotExpired(deadline)

	emission.MintAndDistributeGns(cross)

	// position should be burned to reposition
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
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	poolKey := position.PoolKey()

	change := p.addLiquidity(
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

	position.SetFeeGrowthInside0LastX128(change.feeGrowthInside0LastX128Str)
	position.SetFeeGrowthInside1LastX128(change.feeGrowthInside1LastX128Str)

	position.SetLiquidity(change.liquidity.ToString())

	// OBS: do not reset feeGrowthInside1LastX128 and feeGrowthInside1LastX128 to zero
	// if so, ( decrease 100% -> reposition )
	// > at this point, that position will have unclaimedFee which isn't intended
	position.SetTokensOwed0(0)
	position.SetTokensOwed1(0)
	position.SetBurned(false)
	p.mustUpdatePosition(positionId, *position)

	poolSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(poolKey)
	poolToken0Balance := pl.GetBalanceToken0(poolKey)
	poolToken1Balance := pl.GetBalanceToken1(poolKey)

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp := pl.GetObservation(poolKey, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"Reposition",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"tickLower", formatInt(tickLower),
		"tickUpper", formatInt(tickUpper),
		"liquidityDelta", change.liquidity.ToString(),
		"amount0", change.amount0.ToString(),
		"amount1", change.amount1.ToString(),
		"prevTickLower", formatInt(oldTickLower),
		"prevTickUpper", formatInt(oldTickUpper),
		"poolPath", poolKey,
		"sqrtPriceX96", poolSqrtPriceX96,
		"positionLiquidity", p.GetPositionLiquidity(positionId),
		"poolLiquidity", pl.GetLiquidity(poolKey),
		"token0Balance", formatInt(poolToken0Balance),
		"token1Balance", formatInt(poolToken1Balance),
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
	)

	return positionId, change.liquidity.ToString(), tickLower, tickUpper, change.amount0.ToString(), change.amount1.ToString()
}
