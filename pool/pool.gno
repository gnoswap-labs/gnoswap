package pool

import (
	"std"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	g "gno.land/r/gov"
)

// only position contract can call this function
func Mint(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityAmount bigint,
) (bigint, bigint) {
	require(PrevRealmPath() == "gno.land/r/position", ufmt.Sprintf("[POOL] pool.gno__Mint() || PrevRealmPath(%s) == \"gno.land/r/position\"", PrevRealmPath()))

	require(liquidityAmount > 0, ufmt.Sprintf("[POOL] pool.gno__Mint() || liquidityAmount(%s) > 0", liquidityAmount))

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
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__Mint() || amount0(%d) >= 0", amount0))
	amount1 := bigint(amount1Int)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__Mint() || amount1(%d) >= 0", amount1))

	var balance0Before, balance1Before bigint
	if amount0 > 0 {
		balance0Before := bigint(balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr()))

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pToken0Path, from, to, uint64(amount0))
		if !ok {
			panic("[POOL] pool.gno__Mint() || transferFromByRegisterCall(pToken0Path, from, to, uint64(amount0)) failed")
		}

		require(
			balance0Before+amount0 <= bigint(balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr())(%d)",
				balance0Before, amount0, balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr()),
			),
		)
	}

	if amount1 > 0 {
		balance1Before = bigint(balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr()))

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pToken1Path, from, to, uint64(amount1))
		if !ok {
			panic("[POOL] pool.gno__Mint() ||  transferFromByRegisterCall(pToken1Path, from, to, uint64(amount1)) failed")
		}

		require(
			balance1Before+amount1 <= bigint(balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr())(%d)",
				balance1Before, amount1, balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr()),
			),
		)
	}

	pool.balances.token0 += amount0
	pool.balances.token1 += amount1

	return amount0, amount1
}

// only position contract can call this function
func Burn(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	tickLower int32,
	tickUpper int32,
	amount bigint,
) (bigint, bigint) {
	require(PrevRealmPath() == "gno.land/r/position", ufmt.Sprintf("[POOL] pool.gno__Burn() || caller(%s) must be position contract", PrevRealmPath()))

	requireUnsigned(amount, ufmt.Sprintf("[POOL] pool.gno__Burn() || amount(%s) >= 0", amount))

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	position, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			PrevRealmAddr(), // msg.sender
			tickLower,
			tickUpper,
			-amount,
		},
	)

	amount0, amount1 := -amount0Int, -amount1Int
	requireUnsigned(amount0, ufmt.Sprintf("pool.gno__Burn() || amount0(%s) >= 0", amount0))
	requireUnsigned(amount1, ufmt.Sprintf("pool.gno__Burn() || amount1(%s) >= 0", amount1))

	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 += amount0
		position.tokensOwed1 += amount1
	}

	key := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	pool.positions[key] = position

	return amount0, amount1
}

// only position contract can call this function
func Collect(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	require(PrevRealmPath() == "gno.land/r/position", ufmt.Sprintf("[POOL] pool.gno__Collect() || caller(%s) must be position contract(gno.land/r/position)", PrevRealmPath()))

	requireUnsigned(amount0Requested, ufmt.Sprintf("pool.gno__Collect() || amount0Requested(%s) >= 0", amount0Requested))
	requireUnsigned(amount1Requested, ufmt.Sprintf("pool.gno__Collect() || amount1Requested(%s) >= 0", amount1Requested))

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	key := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] pool.gno__Collect() || position(%s) does not exist", key))

	amount0 := min(amount0Requested, position.tokensOwed0)
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount0(%s) >= 0", amount0))

	amount1 := min(amount1Requested, position.tokensOwed1)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__Collect() || amount1(%s) >= 0", amount1))

	require(pool.balances.token0 >= amount0, ufmt.Sprintf("[POOL] pool.gno__Collect() || pool.balances.token0(%s) >= amount0(%s)", pool.balances.token0, amount0))
	transferByRegisterCall(pToken0Path, recipient, uint64(amount0))

	require(pool.balances.token1 >= amount1, ufmt.Sprintf("[POOL] pool.gno__Collect() || pool.balances.token1(%s) >= amount1(%s)", pool.balances.token1, amount1))
	transferByRegisterCall(pToken1Path, recipient, uint64(amount1))

	// adjust position
	position.tokensOwed0 -= amount0
	position.tokensOwed1 -= amount1
	pool.positions[key] = position

	// adjust pool
	pool.balances.token0 -= amount0
	pool.balances.token1 -= amount1

	requireUnsigned(pool.balances.token0, ufmt.Sprintf("[POOL] pool.gno__Burn() || pool.balances.token0(%s) >= 0", pool.balances.token0))
	requireUnsigned(pool.balances.token1, ufmt.Sprintf("[POOL] pool.gno__Burn() || pool.balances.token1(%s) >= 0", pool.balances.token1))

	return amount0, amount1
}

func Swap(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "[POOL] pool.gno__Swap() || amountSpecified can't be zero")

	pool := GetPool(pToken0Path, pToken1Path, pFee)
	require(pool.liquidity > 0, ufmt.Sprintf("[POOL] math_logic.gno__swapAmount() || pool.liquidity(%d) must be > 0", pool.liquidity))

	slot0Start := pool.slot0
	require(slot0Start.unlocked, "[POOL] pool.gno__Swap() || slot0 must be unlocked")

	var feeProtocol uint8
	var feeGrowthGlobalX128 bigint

	if zeroForOne {
		require(
			sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(T)__sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > MIN_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MIN_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128
	} else {
		require(
			sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(F)__sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < MAX_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MAX_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol / 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal1X128
	}

	pool.slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: pool.liquidity,
		feeProtocol:    feeProtocol,
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

	for state.amountSpecifiedRemaining != 0 && state.amountSpecifiedRemaining != -1 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		var step StepComputations

		step.sqrtPriceStartX96 = state.sqrtPriceX96

		step.tickNext, step.initialized = pool.tickBitmapNextInitializedTickWithInOneWord(
			state.tick,
			pool.tickSpacing,
			zeroForOne,
		)

		if step.tickNext < MIN_TICK {
			step.tickNext = MIN_TICK
		} else if step.tickNext > MAX_TICK {
			step.tickNext = MAX_TICK
		}

		step.sqrtPriceNextX96 = TickMathGetSqrtRatioAtTick(step.tickNext)
		var _sqrtRatioTarget bigint

		if zeroForOne {
			if step.sqrtPriceNextX96 < sqrtPriceLimitX96 {
				_sqrtRatioTarget = sqrtPriceLimitX96
			} else {
				_sqrtRatioTarget = step.sqrtPriceNextX96
			}
		} else {
			if step.sqrtPriceNextX96 > sqrtPriceLimitX96 {
				_sqrtRatioTarget = sqrtPriceLimitX96
			} else {
				_sqrtRatioTarget = step.sqrtPriceNextX96
			}
		}

		state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = swapMathComputeSwapStep(
			state.sqrtPriceX96,
			_sqrtRatioTarget,
			state.liquidity,
			state.amountSpecifiedRemaining,
			uint32(pool.fee),
		)

		if exactInput {
			state.amountSpecifiedRemaining -= step.amountIn + step.feeAmount
			state.amountCalculated -= step.amountOut
		} else {
			state.amountSpecifiedRemaining += step.amountOut
			state.amountCalculated += (step.amountIn + step.feeAmount)
		}

		require(step.amountIn != 0 && step.amountOut != 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || step.amountIn(%d) != 0 && step.amountOut(%d) != 0", step.amountIn, step.amountOut))

		if cache.feeProtocol > 0 {
			delta := step.feeAmount / bigint(uint64(cache.feeProtocol))
			requireUnsigned(delta, ufmt.Sprintf("[POOL] pool.gno__Swap() || delta(%s) >= 0", delta))
			step.feeAmount -= delta
			state.protocolFee += delta
		}

		if state.liquidity > 0 {
			// save fee
			state.feeGrowthGlobalX128 += (step.feeAmount * Q128 / state.liquidity)
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
			state.tick = TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
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
		if amount1 < 0 {
			require(pool.balances.token1 > (-amount1), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%s) > (-1 * amount1)(%s)", pool.balances.token1, (-amount1)))

			ok := transferByRegisterCall(pToken1Path, recipient, uint64(-amount1))
			if !ok {
				panic("[POOL] pool.gno__Swap() || transferByRegisterCall(pToken1Path, recipient, uint64(-amount1)) failed")
			}

			pool.balances.token1 += amount1
		}

		balance0Before := bigint(balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr()))

		txOrigin := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		poolPkg := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pToken0Path, txOrigin, poolPkg, uint64(amount0))
		if !ok {
			panic("[POOL] pool.gno__Swap() ||  transferFromByRegisterCall(pToken0Path, from, to, uint64(amount0)) failed")
		}

		require(
			balance0Before+amount0 <= bigint(balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr())(%d)",
				balance0Before, amount0, balanceOfByRegisterCall(pToken0Path, GetOrigPkgAddr()),
			),
		)

		pool.balances.token0 += amount0
		require(pool.balances.token0 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%s) >= 0__#1", pool.balances.token0))
		require(pool.balances.token1 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%s) >= 0__#1", pool.balances.token1))

	} else {
		if amount0 < 0 {
			require(pool.balances.token0 > (-amount0), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%s) > (-1 * amount0)(%s)", pool.balances.token0, (-amount0)))

			ok := transferByRegisterCall(pToken0Path, recipient, uint64(-amount0))
			if !ok {
				panic("[POOL] pool.gno__Swap() || transferByRegisterCall(pToken0Path, recipient, uint64(-amount0)) failed")
			}

			pool.balances.token0 += amount0
		}

		balance1Before := bigint(balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr()))

		txOrigin := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		poolPkg := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pToken1Path, txOrigin, poolPkg, uint64(amount1))
		if !ok {
			panic("[POOL] pool.gno__Swap() ||  transferFromByRegisterCall(pToken1Path, from, to, uint64(amount1)) failed")
		}

		require(
			balance1Before+amount1 <= bigint(balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr())),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr())(%d)",
				balance1Before, amount1, balanceOfByRegisterCall(pToken1Path, GetOrigPkgAddr()),
			),
		)

		pool.balances.token1 += amount1

		require(pool.balances.token0 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%s) >= 0__#2", pool.balances.token0))
		require(pool.balances.token1 >= 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%s) >= 0__#2", pool.balances.token1))
	}

	pool.slot0.unlocked = true
	return amount0, amount1
}

// ADMIN
func SetFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	require(isAdmin(PrevRealmAddr()), ufmt.Sprintf("[POOL] pool.gno__SetFeeProtocol() || caller(%s) must be admin", PrevRealmAddr()))

	require(
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) && (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		"Invalid fee protocol",
	)

	// iterate all pool
	for _, pool := range pools {
		pool.slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )
	}

	// update governace value
	g.SetGovParameter("protocoL_fees", feeProtocol0+(feeProtocol1<<4))
}

// ADMIN
func CollectProtocol(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	requireUnsigned(amount0Requested, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount0Requested(%s) >= 0", amount0Requested))
	requireUnsigned(amount1Requested, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount1Requested(%s) >= 0", amount1Requested))
	require(isAdmin(PrevRealmAddr()), ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || caller(%s) must be admin", PrevRealmAddr()))

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	amount0 := min(amount0Requested, pool.protocolFees.token0)
	requireUnsigned(amount0, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount0(%s) >= 0", amount0))

	amount1 := min(amount1Requested, pool.protocolFees.token1)
	requireUnsigned(amount1, ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || amount1(%s) >= 0", amount1))

	// without procotol fee
	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)

	ok := transferByRegisterCall(pToken0Path, recipient, uint64(amount0))
	if !ok {
		panic("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pToken0Path, recipient, uint64(amount0)) failed")
	}

	ok = transferByRegisterCall(pToken1Path, recipient, uint64(amount1))
	if !ok {
		panic("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pToken1Path, recipient, uint64(amount1)) failed")
	}

	return amount0, amount1
}

func (pool *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, bigint, bigint) {
	position := pool.updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		pool.slot0.tick,
	)

	var amount0, amount1 bigint

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
	liquidityDelta bigint,
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

// r3v4_xxx
// unused for now
func transfer(token *grc20.AdminToken, amount bigint) {
	balanceBefore, err := token.BalanceOf(GetOrigPkgAddr())
	if err != nil {
		balanceBefore = 0
	}
	from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
	to := GetOrigPkgAddr()

	token.TransferFrom(GetOrigPkgAddr(), from, to, uint64(amount))

	balancAfter, err := token.BalanceOf(GetOrigPkgAddr())
	if err != nil {
		balancAfter = 0
	}
	require(
		balanceBefore+uint64(amount) <= balancAfter,
		ufmt.Sprintf(
			"[POOL] pool.gno__mint() || balanceBefore(%s) + amount(%s) <= balancAfter(%s)",
		),
	)
}

// r3v4_xxx
// unused for now
func (pool *Pool) collect(token *grc20.AdminToken, poolBalance, requestAmount bigint, recipient std.Address) {
	require(poolBalance >= requestAmount, ufmt.Sprintf("[POOL] pool.gno__collect() || poolBalance(%s) >= requestAmount(%s)", poolBalance, requestAmount))
	token.Transfer(GetOrigPkgAddr(), recipient, uint64(requestAmount))
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

func checkTicks(tickLower, tickUpper bigint) {
	require(tickLower < tickUpper, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%s) < tickUpper(%s)", tickLower, tickUpper))
	require(tickLower >= MIN_TICK, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%s) >= MIN_TICK(%s)", tickLower, MIN_TICK))
	require(tickUpper <= MAX_TICK, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickUpper(%s) <= MAX_TICK(%s)", tickUpper, MAX_TICK))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}
