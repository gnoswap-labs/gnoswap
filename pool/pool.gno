package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
	g "gno.land/r/demo/gov"

	"gno.land/p/demo/u256"
)

// only position contract can call this function
func Mint(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityAmount_ bigint,
) (bigint, bigint /* *u256.Int, *u256.Int */) {
	require(PrevRealmPath() == "gno.land/r/demo/position", ufmt.Sprintf("[POOL] pool.gno__Mint() || PrevRealmPath(%s) == \"gno.land/r/demo/position\"", PrevRealmPath()))

	require(liquidityAmount_ > 0, ufmt.Sprintf("[POOL] pool.gno__Mint() || liquidityAmount(%d) > 0", liquidityAmount_))

	liquidityAmount := u256.IntFromBigint(liquidityAmount_)

	pool := GetPool(pToken0Path, pToken1Path, pFee)
	_, amount0, amount1 := pool.modifyPosition(
		ModifyPositionParams{
			recipient,       // owner
			tickLower,       // tickLower
			tickUpper,       // tickUpper
			liquidityAmount, // liquidityDelta
		},
	)

	if amount0.IsNeg() {
		panic("[POOL] pool.gno__Mint() || amount0.IsNeg()")
	}

	if amount1.IsNeg() {
		panic("[POOL] pool.gno__Mint() || amount1.IsNeg()")
	}

	balance0Before := u256.Zero().Int()
	balance1Before := u256.Zero().Int()

	if amount0.Signum() > 0 {
		balance0Before := u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token0Path, from, to, uint64(amount0.Int64()))
		if !ok {
			panic("[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token0Path, from, to, uint64(amount0)) failed")
		}

		require(
			new(u256.Int).Add(balance0Before, amount0).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())(%d)",
				balance0Before, amount0, balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
	}

	if amount1.Signum() > 0 {
		balance1Before = u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token1Path, from, to, uint64(amount1.Int64()))
		if !ok {
			panic("[POOL] pool.gno__Mint() ||  transferFromByRegisterCall(pool.token1Path, from, to, uint64(amount1)) failed")
		}

		require(
			new(u256.Int).Add(balance1Before, amount1).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())(%d)",
				balance1Before, amount1, balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
	}

	pool.balances.token0.AddInt(pool.balances.token0, amount0)
	pool.balances.token1.AddInt(pool.balances.token1, amount1)

	return amount0.Bigint(), amount1.Bigint()
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
	require(PrevRealmPath() == "gno.land/r/demo/position", ufmt.Sprintf("[POOL] pool.gno__Burn() || caller(%s) must be position contract", PrevRealmPath()))

	burnAmount := u256.FromBigint(amount).Int().Neg()

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	position, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			PrevRealmAddr(), // msg.sender
			tickLower,
			tickUpper,
			burnAmount,
		},
	)

	amount0 := amount0Int.Neg().Uint()
	amount1 := amount1Int.Neg().Uint()

	position.tokensOwed0.Add(position.tokensOwed0, amount0)
	position.tokensOwed1.Add(position.tokensOwed1, amount1)

	key := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	pool.positions[key] = position

	return amount0.Bigint(), amount1.Bigint()
}

// only position contract can call this function
func Collect(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested_ bigint,
	amount1Requested_ bigint,
) (bigint, bigint) {
	require(PrevRealmPath() == "gno.land/r/demo/position", ufmt.Sprintf("[POOL] pool.gno__Collect() || caller(%s) must be position contract(gno.land/r/demo/position)", PrevRealmPath()))

	amount0Requested := u256.FromBigint(amount0Requested_)
	amount1Requested := u256.FromBigint(amount1Requested_)

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	key := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] pool.gno__Collect() || position(%s) does not exist", key))

	amount0 := amount0Requested.Min(position.tokensOwed0)
	amount1 := amount1Requested.Min(position.tokensOwed1)

	require(pool.balances.token0.Gte(amount0), ufmt.Sprintf("[POOL] pool.gno__Collect() || pool.balances.token0(%d) >= amount0(%d)", pool.balances.token0, amount0))
	transferByRegisterCall(pool.token0Path, recipient, uint64(amount0))

	require(pool.balances.token1.Gte(amount1), ufmt.Sprintf("[POOL] pool.gno__Collect() || pool.balances.token1(%d) >= amount1(%d)", pool.balances.token1, amount1))
	transferByRegisterCall(pool.token1Path, recipient, uint64(amount1))

	// adjust position
	position.tokensOwed0.Sub(position.tokensOwed0, amount0)
	position.tokensOwed1.Sub(position.tokensOwed1, amount1)
	pool.positions[key] = position

	// adjust pool
	pool.balances.token0.Sub(pool.balances.token0, amount0)
	pool.balances.token1.Sub(pool.balances.token0, amount1)

	return amount0.Bigint(), amount1.Bigint()
}

func Swap(
	pToken0Path string,
	pToken1Path string,
	pFee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified_ bigint,
	sqrtPriceLimitX96_ bigint,
	payer std.Address, // router
) (bigint, bigint) {
	require(PrevRealmPath() == "gno.land/r/demo/router", ufmt.Sprintf("[POOL] pool.gno__Swap() || caller(%s) must be router contract(gno.land/r/demo/router)", PrevRealmPath()))

	require(amountSpecified_ != 0, "[POOL] pool.gno__Swap() || amountSpecified can't be zero")

	amountSpecified := u256.IntFromBigint(amountSpecified_)
	sqrtPriceLimitX96 := u256.FromBigint(sqrtPriceLimitX96_)

	pool := GetPool(pToken0Path, pToken1Path, pFee)
	slot0Start := pool.slot0
	require(slot0Start.unlocked, "[POOL] pool.gno__Swap() || slot0 must be unlocked")

	var feeProtocol uint8
	var feeGrowthGlobalX128 *u256.Uint

	if zeroForOne {
		require(
			sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Gt(u256.FromBigint(consts.MIN_SQRT_RATIO)),
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(T)__sqrtPriceLimitX96(%d) < slot0Start.sqrtPriceX96(%d) && sqrtPriceLimitX96(%d) > MIN_SQRT_RATIO(%d)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, consts.MIN_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128
	} else {
		require(
			sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Lt(u256.FromBigint(consts.MAX_SQRT_RATIO)),
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(F)__sqrtPriceLimitX96(%d) > slot0Start.sqrtPriceX96(%d) && sqrtPriceLimitX96(%d) < MAX_SQRT_RATIO(%d)",
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

	exactInput := amountSpecified.Gt(u256.Zero().Int())

	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         u256.Zero().Int(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal0X128,
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         u256.Zero().Int(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal1X128,
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	}

	for !state.amountSpecifiedRemaining.IsZero() && !state.sqrtPriceX96.Eq(sqrtPriceLimitX96) {
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

		step.sqrtPriceNextX96 = TickMathGetSqrtRatioAtTick(step.tickNext)
		isLower := step.sqrtPriceNextX96 < sqrtPriceLimitX96
		isHigher := step.sqrtPriceNextX96 > sqrtPriceLimitX96

		var sqrtRatioTargetX96 *u256.Uint
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
			state.amountSpecifiedRemaining.Sub(state.amountSpecifiedRemaining, new(u256.Uint).Add(step.amountIn, step.feeAmount).Int())
			state.amountCalculated.Sub(state.amountCalculated, step.amountOut.Int())
		} else {
			state.amountSpecifiedRemaining.Add(state.amountSpecifiedRemaining, step.amountOut.Int())
			state.amountCalculated.Add(state.amountCalculated, new(u256.Uint).Add(step.amountIn, step.feeAmount).Int())
		}

		if cache.feeProtocol > 0 {
			delta := new(u256.Uint).Div(step.feeAmount, u256.NewUint(uint64(cache.feeProtocol)))
			step.feeAmount.Sub(step.feeAmount, delta)
			state.protocolFee.Add(state.protocolFee, delta)
		}

		if state.liquidity.Gt(u256.Zero()) {
			// save fee
			update := new(u256.Uint).Mul(step.feeAmount, u256.FromBigint(consts.Q128))
			update.Div(update, state.liquidity)
			state.feeGrowthGlobalX128.Add(state.feeGrowthGlobalX128, update)
		}

		if state.sqrtPriceX96 == step.sqrtPriceNextX96 {
			if step.initialized {
				var fee0, fee1 *u256.Uint

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
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token0 += state.protocolFee
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token1 += state.protocolFee
		}
	}

	var amount0, amount1 *u256.Int
	if zeroForOne == exactInput {
		amount0 = new(u256.Int).Sub(amountSpecified, state.amountSpecifiedRemaining)
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = new(u256.Int).Sub(amountSpecified, state.amountSpecifiedRemaining)
	}

	if zeroForOne {
		// payer > pool
		balance0Before := balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token0Path, payer, consts.ADDR_POOL, uint64(amount0))
		if !ok {
			panic("[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token0Path, payer, ADDR_POOL, uint64(amount0)) failed")
		}

		require(
			new(u256.Int).Add(u256.NewUint(balance0Before).Int(), amount0).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())(%d)",
				balance0Before, amount0, balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token0.AddInt(pool.balances.token0, amount0)

		if amount1.IsNeg() { // pool > recipient
			require(pool.balances.token1.Gt(amount1.Abs()), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) > (-1 * amount1)(%d)", pool.balances.token1, (-amount1)))
			ok := transferByRegisterCall(pool.token1Path, recipient, uint64(-amount1))
			if !ok {
				panic("[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token1Path, recipient, uint64(-amount1)) failed")
			}
			pool.balances.token1.AddInt(pool.balances.token1, amount1)

		}

	} else {
		// payer > pool
		balance1Before := balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token1Path, payer, consts.ADDR_POOL, uint64(amount1))
		if !ok {
			panic("[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token1Path, payer, ADDR_POOL, uint64(amount1)) failed")
		}

		require(
			new(u256.Int).Add(u256.NewUint(balance1Before).Int(), amount1).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())(%d)",
				balance1Before, amount1, balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token1.AddInt(pool.balances.token1, amount1)

		if amount0.IsNeg() { // pool > recipient
			require(pool.balances.token0.Gt(amount0.Abs()), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) > (-1 * amount0)(%d)", pool.balances.token0, (-amount0)))

			ok := transferByRegisterCall(pool.token0Path, recipient, uint64(-amount0))
			if !ok {
				panic("[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token0Path, recipient, uint64(-amount0)) failed")
			}
			pool.balances.token0.AddInt(pool.balances.token0, amount0)
		}
	}

	pool.slot0.unlocked = true
	return amount0.Bigint(), amount1.Bigint()
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
	amount0Requested *u256.Uint,
	amount1Requested *u256.Uint,
) (bigint, bigint) {
	require(isAdmin(PrevRealmAddr()), ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || caller(%s) must be admin", PrevRealmAddr()))

	pool := GetPool(pToken0Path, pToken1Path, pFee)

	amount0 := amount0Requested.Min(pool.protocolFees.token0)
	amount1 := amount1Requested.Min(pool.protocolFees.token1)

	// without procotol fee
	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)

	ok := transferByRegisterCall(pool.token0Path, recipient, uint64(amount0))
	if !ok {
		panic("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token0Path, recipient, uint64(amount0)) failed")
	}

	ok = transferByRegisterCall(pool.token1Path, recipient, uint64(amount1))
	if !ok {
		panic("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token1Path, recipient, uint64(amount1)) failed")
	}

	return amount0.Bigint(), amount1.Bigint()
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

	amount0 := u256.Zero().Int()
	amount1 := u256.Zero().Int()

	if !params.liquidityDelta.IsZero() {
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
	var _feeGrowthGlobal0X128 *u256.Uint = pool.feeGrowthGlobal0X128
	var _feeGrowthGlobal1X128 *u256.Uint = pool.feeGrowthGlobal1X128

	var flippedLower, flippedUpper bool

	if !liquidityDelta.IsZero() {
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

	if liquidityDelta.IsNeg() {
		if flippedLower {
			pool.tickClear(tickLower)
		}

		if flippedUpper {
			pool.tickClear(tickUpper)
		}
	}
	return position
}

func (pool *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	if !amount0.IsZero() && amount0.Eq(pool.protocolFees.token0) {
		amount0--
	}

	if !amount1.IsZero() && amount1.Eq(pool.protocolFees.token1) {
		amount1--
	}

	pool.protocolFees.token0.Sub(pool.protocolFees.token0, amount0)
	pool.protocolFees.token1.Sub(pool.protocolFees.token1, amount1)

	// return rest fee
	return amount0, amount1
}

func abs(x bigint) uint64 {
	if x < 0 {
		return uint64(-x)
	}
	return uint64(x)
}
