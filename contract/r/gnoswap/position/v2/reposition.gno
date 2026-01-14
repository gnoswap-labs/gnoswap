package v2

import (
	"chain"
	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

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

	// assert that the user has sent the correct amount of native coin
	token0, token1, _ := splitOf(position.PoolKey())
	assertIsValidUserCoinSendWithWrappedTokenPair(token0, token1, amount0DesiredStr, amount1DesiredStr)

	receivedCoins := common.ExistsUserSendCoins()
	if receivedCoins {
		if common.IsGNOTPath(token0) {
			token0 = common.GNOT_DENOM
		} else if common.IsGNOTPath(token1) {
			token1 = common.GNOT_DENOM
		}
	}

	oldTickLower := position.TickLower()
	oldTickUpper := position.TickUpper()

	if !position.IsClear() {
		panic(newErrorWithDetail(
			errNotClear,
			ufmt.Sprintf(
				"position(%d) isn't clear(liquidity:%s, tokensOwed0:%s, tokensOwed1:%s)",
				positionId,
				position.Liquidity().ToString(),
				position.TokensOwed0().ToString(),
				position.TokensOwed1().ToString(),
			),
		))
	}

	token0, token1, _, _, _, err := p.processTokens(
		token0,
		token1,
		amount0DesiredStr,
		amount1DesiredStr,
		caller,
	)
	if err != nil {
		panic(err)
	}

	poolKey := position.PoolKey()

	liquidity, amount0, amount1 := p.addLiquidity(
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
		panic(newErrorWithDetail(err, "failed to get current fee growth"))
	}
	position.SetFeeGrowthInside0LastX128(currentFeeGrowth.feeGrowthInside0LastX128)
	position.SetFeeGrowthInside1LastX128(currentFeeGrowth.feeGrowthInside1LastX128)

	position.SetLiquidity(liquidity)
	// OBS: do not reset feeGrowthInside1LastX128 and feeGrowthInside1LastX128 to zero
	// if so, ( decrease 100% -> reposition )
	// > at this point, that position will have unclaimedFee which isn't intended
	position.SetTokensOwed0(u256.Zero())
	position.SetTokensOwed1(u256.Zero())
	position.SetBurned(false)
	p.mustUpdatePosition(positionId, *position)

	poolSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(poolKey)
	token0Balance := pl.GetBalanceToken0(poolKey)
	token1Balance := pl.GetBalanceToken1(poolKey)

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp :=
		pl.GetObservation(poolKey, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"Reposition",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"tickLower", formatInt(tickLower),
		"tickUpper", formatInt(tickUpper),
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"prevTickLower", formatInt(oldTickLower),
		"prevTickUpper", formatInt(oldTickUpper),
		"poolPath", poolKey,
		"sqrtPriceX96", poolSqrtPriceX96.ToString(),
		"positionLiquidity", p.GetPositionLiquidity(positionId).ToString(),
		"token0Balance", token0Balance,
		"token1Balance", token1Balance,
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
	)

	return positionId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
}
