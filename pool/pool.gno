package pool

import (
	"std"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/u256"
)

// only position contract can call this function
func Mint(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityAmount_ bigint,
) (bigint, bigint /* *u256.Int, *u256.Int */) {
	require(PrevRealmPath() == "gno.land/r/demo/position", ufmt.Sprintf("[POOL] pool.gno__Mint() || PrevRealmPath(%s) == \"gno.land/r/demo/position\"", PrevRealmPath()))

	requirePositive(liquidityAmount, ufmt.Sprintf("[POOL] pool.gno__Mint() || expected liquidityAmount(%d) > 0", liquidityAmount))

	liquidityAmount := u256.FromBigint(liquidityAmount_)

	pool := GetPool(pToken0Path, pToken1Path, pFee)
	_, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			recipient,       // owner
			tickLower,       // tickLower
			tickUpper,       // tickUpper
			liquidityAmount, // liquidityDelta
		},
	)

	amount0 := bigint(amount0Int)
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__Mint() || expected amount0(%d) >= 0", amount0))
	amount1 := bigint(amount1Int)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__Mint() || expected amount1(%d) >= 0", amount1))

	var balance0Before, balance1Before u256.Int
	if amount0 > 0 {
		balance0Before := bigint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()))

		from := std.GetOrigCaller() // token should be transferred from actual user(std.GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token0Path, from, to, uint64(amount0))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token0Path(%s), from(%s), to(%s), uint64(amount0))(%d) failed",
				pool.token0Path, from.String(), to.String(), uint64(amount0),
			),
		)

		require(
			balance0Before+amount0 <= bigint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance0Before, amount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
	}

	if amount1 > 0 {
		balance1Before = bigint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()))

		from := std.GetOrigCaller() // token should be transferred from actual user(std.GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token1Path, from, to, uint64(amount1))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token1Path(%s), from(%s), to(%s), uint64(amount1))(%d) failed",
				pool.token1Path, from.String(), to.String(), uint64(amount1),
			),
		)

		require(
			balance1Before+amount1 <= bigint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance1Before, amount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
	}

	pool.balances.token0 += amount0
	pool.balances.token1 += amount1

	return amount0, amount1
}

// only position contract can call this function
func Burn(
	token0Path string,
	token1Path string,
	fee uint16,
	tickLower int32,
	tickUpper int32,
	amount bigint,
) (bigint, bigint) {
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] pool.gno__Burn() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, std.PrevRealm().PkgPath()))

	requireUnsigned(amount, ufmt.Sprintf("[POOL] pool.gno__Burn() || amount(%d) >= 0", amount))

	pool := GetPool(token0Path, token1Path, fee)

	position, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			std.PrevRealm().Addr(), // msg.sender
			tickLower,
			tickUpper,
			-amount,
		},
	)

	amount0, amount1 := -amount0Int, -amount1Int
	requireUnsigned(amount0, ufmt.Sprintf("pool.gno__Burn() || amount0(%d) >= 0", amount0))
	requireUnsigned(amount1, ufmt.Sprintf("pool.gno__Burn() || amount1(%d) >= 0", amount1))

	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 += amount0
		position.tokensOwed1 += amount1
	}

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	pool.positions[positionKey] = position

	// actual token transfer happens in Collect()
	return amount0, amount1
}

// only position contract can call this function
func Collect(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] pool.gno__Collect() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, std.PrevRealm().PkgPath()))

	requireUnsigned(amount0Requested, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount0Requested(%d) >= 0", amount0Requested))
	requireUnsigned(amount1Requested, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount1Requested(%d) >= 0", amount1Requested))

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	requireExist(exist, ufmt.Sprintf("[POOL] pool.gno__Collect() || position(%s) does not exist", positionKey))

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0 := min(amount0Requested, position.tokensOwed0)
	amount0 = min(amount0, pool.balances.token0)
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount0(%d) >= 0", amount0))

	// Update state first then transfer
	position.tokensOwed0 -= amount0
	pool.balances.token0 -= amount0
	transferByRegisterCall(pool.token0Path, recipient, uint64(amount0))
	requireUnsigned(pool.balances.token0, ufmt.Sprintf("[POOL] pool.gno__Burn() || pool.balances.token0(%d) >= 0", pool.balances.token0))

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1 := min(amount1Requested, position.tokensOwed1)
	amount1 = min(amount1, pool.balances.token1)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount1(%d) >= 0", amount1))

	// Update state first then transfer
	position.tokensOwed1 -= amount1
	pool.balances.token1 -= amount1
	transferByRegisterCall(pool.token1Path, recipient, uint64(amount1))
	requireUnsigned(pool.balances.token1, ufmt.Sprintf("[POOL] pool.gno__Burn() || pool.balances.token1(%d) >= 0", pool.balances.token1))

	pool.positions[positionKey] = position

	return amount0, amount1
}

func Swap(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
	payer std.Address, // router
) (bigint, bigint) {
	requirePrevRealmPath(consts.ROUTER_PATH, ufmt.Sprintf("[POOL] pool.gno__Swap() || expected PrevRealmPath(%s), got %s", consts.ROUTER_PATH, std.PrevRealm().PkgPath()))

	// early panic
	require(amountSpecified != 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || amountSpecified(%d) != 0", amountSpecified))

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0
	require(slot0Start.unlocked, ufmt.Sprintf("[POOL] pool.gno__Swap() || slot0 must be unlocked"))

	var feeProtocol uint8
	var feeGrowthGlobalX128 bigint

	if zeroForOne {
		require(
			sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > consts.MIN_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || sqrtPriceLimitX96(%d) < slot0Start.sqrtPriceX96(%d) && sqrtPriceLimitX96(%d) > consts.MIN_SQRT_RATIO(%d)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, consts.MIN_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128
	} else {
		require(
			sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < consts.MAX_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || sqrtPriceLimitX96(%d) > slot0Start.sqrtPriceX96(%d) && sqrtPriceLimitX96(%d) < consts.MAX_SQRT_RATIO(%d)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, consts.MAX_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol / 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal1X128
	}

	pool.slot0.unlocked = false

	var cache SwapCache
	if zeroForOne {
		cache = SwapCache{
			liquidityStart: pool.liquidity,
			feeProtocol:    slot0Start.feeProtocol % 16,
		}
	} else {
		cache = SwapCache{
			liquidityStart: pool.liquidity,
			feeProtocol:    slot0Start.feeProtocol >> 4,
		}
	}

	exactInput := amountSpecified > 0

	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         0,
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal0X128,
			protocolFee:              0,
			liquidity:                cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         0,
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal1X128,
			protocolFee:              0,
			liquidity:                cache.liquidityStart,
		}
	}

	for state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		var step StepComputations

		step.sqrtPriceStartX96 = state.sqrtPriceX96

		step.tickNext, step.initialized = pool.tickBitmapNextInitializedTickWithInOneWord(
			state.tick,
			pool.tickSpacing,
			zeroForOne,
		)

		if step.tickNext < consts.MIN_TICK {
			step.tickNext = consts.MIN_TICK
		} else if step.tickNext > consts.MAX_TICK {
			step.tickNext = consts.MAX_TICK
		}

		step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)
		isLower := step.sqrtPriceNextX96 < sqrtPriceLimitX96
		isHigher := step.sqrtPriceNextX96 > sqrtPriceLimitX96

		var sqrtRatioTargetX96 bigint
		if (zeroForOne && isLower) || (!zeroForOne && isHigher) {
			sqrtRatioTargetX96 = sqrtPriceLimitX96
		} else {
			sqrtRatioTargetX96 = step.sqrtPriceNextX96
		}

		state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = swapMathComputeSwapStep(
			state.sqrtPriceX96,
			sqrtRatioTargetX96,
			state.liquidity,
			state.amountSpecifiedRemaining,
			uint32(pool.fee),
		)

		if exactInput {
			state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount)
			state.amountCalculated -= step.amountOut
		} else {
			state.amountSpecifiedRemaining += step.amountOut
			state.amountCalculated += (step.amountIn + step.feeAmount)
		}

		if cache.feeProtocol > 0 {
			delta := step.feeAmount / bigint(uint64(cache.feeProtocol))
			requireUnsigned(delta, ufmt.Sprintf("[POOL] pool.gno__Swap() || delta(%d) >= 0", delta))
			step.feeAmount -= delta
			state.protocolFee += delta
		}

		if state.liquidity > 0 {
			// save fee
			state.feeGrowthGlobalX128 += (step.feeAmount * consts.Q128 / state.liquidity)
		}

		if state.sqrtPriceX96 == step.sqrtPriceNextX96 {
			if step.initialized {
				var fee0, fee1 bigint

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

				if zeroForOne {
					liquidityNet = -liquidityNet
				}

				state.liquidity = liquidityMathAddDelta(state.liquidity, liquidityNet)
			}

			if zeroForOne {
				state.tick = step.tickNext - 1
			} else {
				state.tick = step.tickNext
			}
		} else if state.sqrtPriceX96 != step.sqrtPriceStartX96 {
			state.tick = common.TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
		}
	}

	// END LOOP
	pool.slot0.sqrtPriceX96 = state.sqrtPriceX96
	if state.tick != slot0Start.tick {
		pool.slot0.tick = state.tick
	}

	if cache.liquidityStart != state.liquidity {
		pool.liquidity = state.liquidity
	}

	if zeroForOne {
		pool.feeGrowthGlobal0X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			pool.protocolFees.token0 += state.protocolFee
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			pool.protocolFees.token1 += state.protocolFee
		}
	}

	var amount0, amount1 bigint
	if zeroForOne == exactInput {
		amount0 = amountSpecified - state.amountSpecifiedRemaining
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = amountSpecified - state.amountSpecifiedRemaining
	}

	if zeroForOne {
		// payer > pool
		balance0Before := bigint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()))
		ok := transferFromByRegisterCall(pool.token0Path, payer, consts.POOL_ADDR, uint64(amount0))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token0Path(%s), payer(%s), consts.POOL_ADDR(%s), uint64(amount0))(%d) failed",
				pool.token0Path, payer.String(), consts.POOL_ADDR.String(), uint64(amount0),
			),
		)

		require(
			balance0Before+amount0 <= bigint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance0Before, amount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token0 += amount0
		require(pool.balances.token0 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) >= 0", pool.balances.token0))

		if amount1 < 0 { // pool > recipient
			require(pool.balances.token1 > -amount1, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) > -amount1(%d)", pool.balances.token1, -amount1))

			ok := transferByRegisterCall(pool.token1Path, recipient, uint64(-amount1))
			require(
				ok,
				ufmt.Sprintf(
					"[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uint64(-amount1))(%d) failed",
					pool.token1Path, recipient.String(), uint64(-amount1),
				),
			)
			pool.balances.token1 += amount1

		}
		require(pool.balances.token1 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() #1 || pool.balances.token1(%d) >= 0", pool.balances.token1))

	} else {
		// payer > pool
		balance1Before := bigint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()))
		ok := transferFromByRegisterCall(pool.token1Path, payer, consts.POOL_ADDR, uint64(amount1))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token1Path(%s), payer(%s), consts.POOL_ADDR(%s), uint64(amount1))(%d) failed",
				pool.token1Path, payer.String(), consts.POOL_ADDR.String(), uint64(amount1),
			),
		)

		require(
			balance1Before+amount1 <= bigint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance1Before, amount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token1 += amount1
		require(pool.balances.token1 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() #2 || pool.balances.token1(%d) >= 0", pool.balances.token1))

		if amount0 < 0 { // pool > recipient
			require(pool.balances.token0 > -amount0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) > -amount0(%d)", pool.balances.token0, -amount0))

			ok := transferByRegisterCall(pool.token0Path, recipient, uint64(-amount0))
			require(
				ok,
				ufmt.Sprintf(
					"[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uint64(-amount0))(%d) failed",
					pool.token0Path, recipient.String(), uint64(-amount0),
				),
			)
			pool.balances.token0 += amount0
		}
		require(pool.balances.token0 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() #2 || pool.balances.token0(%d) >= 0", pool.balances.token0))
	}

	pool.slot0.unlocked = true
	return amount0, amount1
}

// ADMIN
func SetFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	require(isAdmin(std.PrevRealm().Addr()), ufmt.Sprintf("[POOL] pool.gno__SetFeeProtocol() || caller(%s) must be admin", std.PrevRealm().Addr()))

	require(
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) && (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		ufmt.Sprintf(
			"[POOL] pool.gno__SetFeeProtocol() || expected (feeProtocol0(%d) == 0 || (feeProtocol0(%d) >= 4 && feeProtocol0(%d) <= 10)) && (feeProtocol1(%d) == 0 || (feeProtocol1(%d) >= 4 && feeProtocol1(%d) <= 10))",
			feeProtocol0, feeProtocol0, feeProtocol0, feeProtocol1, feeProtocol1, feeProtocol1,
		),
	)

	// iterate all pool
	for _, pool := range pools {
		pool.slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )
	}

	// update governace value
	gv.SetGovParameter("protocoL_fees", feeProtocol0+(feeProtocol1<<4))
}

// ADMIN
func CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	amount0Requested *u256.Uint,
	amount1Requested *u256.Uint,
) (bigint, bigint) {
	require(isAdmin(PrevRealmAddr()), ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || caller(%s) must be admin", PrevRealmAddr()))

	pool := GetPool(token0Path, token1Path, fee)

	amount0 := min(amount0Requested, pool.protocolFees.token0)
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount0(%d) >= 0", amount0))

	amount1 := min(amount1Requested, pool.protocolFees.token1)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount1(%d) >= 0", amount1))

	// without procotol fee
	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)

	ok := transferByRegisterCall(pool.token0Path, recipient, uint64(amount0))
	require(
		ok,
		ufmt.Sprintf(
			"[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uint64(amount0))(%d) failed",
			pool.token0Path, recipient.String(), uint64(amount0),
		),
	)

	ok = transferByRegisterCall(pool.token1Path, recipient, uint64(amount1))
	require(
		ok,
		ufmt.Sprintf(
			"[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uint64(amount1))(%d) failed",
			pool.token1Path, recipient.String(), uint64(amount1),
		),
	)

	return amount0, amount1
}

// XXXXX: i made some mistake on int/uint while refactoring this part, please double check it before merge
func (pool *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, *u256.Int, *u256.Int) {
	position := pool.updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		pool.slot0.tick,
	)

	amount0 := u256.Zero()
	amount1 := u256.Zero()

	if params.liquidityDelta != 0 {
		if pool.slot0.tick < params.tickLower {
			amount0 = sqrtPriceMathGetAmount0Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		} else if pool.slot0.tick < params.tickUpper {
			liquidityBefore := pool.liquidity

			amount0 = sqrtPriceMathGetAmount0Delta(
				pool.slot0.sqrtPriceX96,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)

			amount1 = sqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPriceX96,
				params.liquidityDelta,
			)

			pool.liquidity = liquidityMathAddDelta(liquidityBefore, params.liquidityDelta)

		} else {
			amount1 = sqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		}
	}

	return position, amount0, amount1
}

func (pool *Pool) updatePosition(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityDelta *u256.Int,
	tick int32,
) PositionInfo {
	var _feeGrowthGlobal0X128 bigint = pool.feeGrowthGlobal0X128
	var _feeGrowthGlobal1X128 bigint = pool.feeGrowthGlobal1X128

	var flippedLower, flippedUpper bool
	if liquidityDelta != 0 {
		flippedLower = pool.tickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			pool.maxLiquidityPerTick,
		)

		flippedUpper = pool.tickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			true,
			pool.maxLiquidityPerTick,
		)

		if flippedLower {
			pool.tickBitmapFlipTick(tickLower, pool.tickSpacing)
		}

		if flippedUpper {
			pool.tickBitmapFlipTick(tickUpper, pool.tickSpacing)
		}
	}

	// NO LIQ, ONLY BURN 0

	feeGrowthInside0X128, feeGrowthInside1X128 := pool.tickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	key := positionGetKey(owner, tickLower, tickUpper)

	position := pool.positionUpdateWithKey(
		key,
		liquidityDelta,
		feeGrowthInside0X128,
		feeGrowthInside1X128,
	)

	if liquidityDelta < 0 {
		if flippedLower {
			pool.tickClear(tickLower)
		}

		if flippedUpper {
			pool.tickClear(tickUpper)
		}
	}
	return position
}

func (pool *Pool) saveProtocolFees(amount0, amount1 bigint) (bigint, bigint) {
	if amount0 > 0 && amount0 == pool.protocolFees.token0 {
		amount0--
	}

	if amount1 > 0 && amount1 == pool.protocolFees.token1 {
		amount1--
	}

	pool.protocolFees.token0 -= amount0
	pool.protocolFees.token1 -= amount1

	// return rest fee
	return amount0, amount1
}

func abs(x bigint) uint64 {
	if x < 0 {
		return uint64(-x)
	}
	return uint64(x)
}
