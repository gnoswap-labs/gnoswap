package pool

import (
	"std"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	g "gno.land/r/demo/gov"

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
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] pool.gno__Mint() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, PrevRealmPath()))

	requirePositive(liquidityAmount_, ufmt.Sprintf("[POOL] pool.gno__Mint() || expected liquidityAmount(%d) > 0", liquidityAmount_))

	liquidityAmount := u256.IntFromBigint(liquidityAmount_)

	pool := GetPool(token0Path, token1Path, fee)
	_, amount0, amount1 := pool.modifyPosition(
		ModifyPositionParams{
			recipient,       // owner
			tickLower,       // tickLower
			tickUpper,       // tickUpper
			liquidityAmount, // liquidityDelta
		},
	)

	if amount0.IsNeg() {
		panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || expected amount0(%d) >= 0", amount0))
	}

	if amount1.IsNeg() {
		panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || expected amount1(%d) >= 0", amount1))
	}

	balance0Before := u256.Zero().Int()
	balance1Before := u256.Zero().Int()

	if amount0.Signum() > 0 {
		balance0Before := u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token0Path, from, to, uint64(amount0.Int64()))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token0Path(%s), from(%s), to(%s), uint64(amount0))(%d) failed",
				pool.token0Path, from.String(), to.String(), uint64(amount0.Int64()),
			),
		)

		require(
			new(u256.Int).Add(balance0Before, amount0).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance0Before, amount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
	}

	if amount1.Signum() > 0 {
		balance1Before = u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()

		from := GetOrigCaller() // token should be transferred from actual user(GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token1Path, from, to, uint64(amount1.Int64()))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token1Path(%s), from(%s), to(%s), uint64(amount1))(%d) failed",
				pool.token1Path, from.String(), to.String(), uint64(amount1.Int64()),
			),
		)

		require(
			new(u256.Int).Add(balance1Before, amount1).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance1Before, amount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
	}

	pool.balances.token0.AddInt(pool.balances.token0, amount0)
	pool.balances.token1.AddInt(pool.balances.token1, amount1)

	return amount0.Bigint(), amount1.Bigint()
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
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] pool.gno__Burn() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, PrevRealmPath()))

	burnAmount := u256.FromBigint(amount).Int().Neg()

	pool := GetPool(token0Path, token1Path, fee)

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

	positionKey := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	pool.positions[positionKey] = position

	// actual token transfer happens in Collect()
	return amount0.Bigint(), amount1.Bigint()
}

// only position contract can call this function
func Collect(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested_ bigint,
	amount1Requested_ bigint,
) (bigint, bigint) {
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] pool.gno__Collect() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, PrevRealmPath()))

	amount0Requested := u256.FromBigint(amount0Requested_)
	amount1Requested := u256.FromBigint(amount1Requested_)

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(PrevRealmAddr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	requireExist(exist, ufmt.Sprintf("[POOL] pool.gno__Collect() || position(%s) does not exist", positionKey))

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	// println("amount0Requested:", amount0Requested.Dec())
	// println("position.tokensOwed0:", position.tokensOwed0.Dec())
	// println("pool.balances.token0:", pool.balances.token0.Dec())
	// println()

	amount0 := amount0Requested.Min(position.tokensOwed0)
	amount0 = amount0.Min(pool.balances.token0)
	amount1 := amount1Requested.Min(position.tokensOwed1)
	amount1 = amount1.Min(pool.balances.token1)

	// backup calculated amount
	resAmount0 := amount0.Clone()
	resAmount1 := amount1.Clone()

	// adjust position
	_amount0 := resAmount0.Clone()
	_amount1 := resAmount1.Clone()
	position.tokensOwed0.Sub(position.tokensOwed0, _amount0)
	position.tokensOwed1.Sub(position.tokensOwed1, _amount1)

	// adjust pool
	_amount0 = resAmount0.Clone()
	_amount1 = resAmount1.Clone()
	pool.balances.token0.Sub(pool.balances.token0, _amount0)
	pool.balances.token1.Sub(pool.balances.token1, _amount1)

	// tranfer
	_amount0 = resAmount0.Clone()
	_amount1 = resAmount1.Clone()
	transferByRegisterCall(pool.token0Path, recipient, _amount0.Uint64())
	transferByRegisterCall(pool.token1Path, recipient, _amount1.Uint64())

	pool.positions[positionKey] = position

	return resAmount0.Bigint(), resAmount1.Bigint()
}

func Swap(
	token0Path string,
	token1Path string,
	fee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified_ bigint,
	sqrtPriceLimitX96_ bigint,
	payer std.Address, // router
) (bigint, bigint) {
	requirePrevRealmPath(consts.ROUTER_PATH, ufmt.Sprintf("[POOL] pool.gno__Swap() || expected PrevRealmPath(%s), got %s", consts.ROUTER_PATH, PrevRealmPath()))

	// early panic
	require(amountSpecified_ != 0, ufmt.Sprintf("[POOL] pool.gno__Swap() || amountSpecified(%d) != 0", amountSpecified_))

	amountSpecified := u256.IntFromBigint(amountSpecified_)
	sqrtPriceLimitX96 := u256.FromBigint(sqrtPriceLimitX96_)

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0
	require(slot0Start.unlocked, ufmt.Sprintf("[POOL] pool.gno__Swap() || slot0 must be unlocked"))

	// println("SQRT:", slot0Start.sqrtPriceX96.Dec())

	var feeProtocol uint8
	var feeGrowthGlobalX128 *u256.Uint

	if zeroForOne {
		require(
			sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Gt(u256.FromBigint(consts.MIN_SQRT_RATIO)),
			ufmt.Sprintf("[POOL] pool.gno__Swap() || sqrtPriceLimitX96(%d) < slot0Start.sqrtPriceX96(%d) && sqrtPriceLimitX96(%d) > consts.MIN_SQRT_RATIO(%d)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, consts.MIN_SQRT_RATIO),
		)
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128
	} else {
		require(
			sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Lt(u256.FromBigint(consts.MAX_SQRT_RATIO)),
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

	exactInput := amountSpecified.Gt(u256.Zero().Int())

	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         u256.Zero().Int(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal0X128.Clone(),
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         u256.Zero().Int(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal1X128.Clone(),
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	}

	// continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
	origAmountSpecified := amountSpecified.Clone()
	for !state.amountSpecifiedRemaining.IsZero() && !state.sqrtPriceX96.Eq(sqrtPriceLimitX96) {
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

		step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)
		isLower := step.sqrtPriceNextX96.Lt(sqrtPriceLimitX96)
		isHigher := step.sqrtPriceNextX96.Gt(sqrtPriceLimitX96)

		// get the price for the next tick
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

		// if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
		if cache.feeProtocol > 0 {
			delta := new(u256.Uint).Div(step.feeAmount, u256.NewUint(uint64(cache.feeProtocol)))
			step.feeAmount.Sub(step.feeAmount, delta)
			state.protocolFee.Add(state.protocolFee, delta)
		}

		// update global fee tracker
		if state.liquidity.Gt(u256.Zero()) {
			// save fee
			update := new(u256.Uint).Mul(step.feeAmount, u256.FromDecimal(string(consts.Q128)))
			update.Div(update, state.liquidity)
			state.feeGrowthGlobalX128.Add(state.feeGrowthGlobalX128.Clone(), update)
		}

		// shift tick if we reached the next price
		if state.sqrtPriceX96 == step.sqrtPriceNextX96 {
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
					liquidityNet = liquidityNet.Neg()
				}

				state.liquidity = liquidityMathAddDelta(state.liquidity, liquidityNet)
			}

			if zeroForOne {
				state.tick = step.tickNext - 1
			} else {
				state.tick = step.tickNext
			}
		} else if state.sqrtPriceX96 != step.sqrtPriceStartX96 {
			// recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
			state.tick = common.TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
		}
	}
	// END LOOP
	println("END")

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
			pool.protocolFees.token0.Add(pool.protocolFees.token0, state.protocolFee)
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token1.Add(pool.protocolFees.token1, state.protocolFee)
		}
	}

	var amount0, amount1 *u256.Int
	if zeroForOne == exactInput {
		amount0 = new(u256.Int).Sub(origAmountSpecified, state.amountSpecifiedRemaining)
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = new(u256.Int).Sub(origAmountSpecified, state.amountSpecifiedRemaining)
	}

	// backUP
	resAmount0 := amount0.Clone()
	resAmount1 := amount1.Clone()

	if zeroForOne {
		// payer > pool
		balance0Before := balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token0Path, payer, consts.POOL_ADDR, uint64(amount0.Int64()))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token0Path(%s), payer(%s), consts.POOL_ADDR(%s), uint64(amount0))(%d) failed",
				pool.token0Path, payer.String(), consts.POOL_ADDR.String(), uint64(amount0.Int64()),
			),
		)

		require(
			new(u256.Int).Add(u256.NewUint(balance0Before).Int(), amount0).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance0Before, amount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token0.AddInt(pool.balances.token0, amount0)

		if amount1.IsNeg() { // pool > recipient
			require(pool.balances.token1.Gt(amount1.Abs()), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) > -amount1(%d)", pool.balances.token1, amount1.Neg()))
			ok := transferByRegisterCall(pool.token1Path, recipient, amount1.Abs().Uint64())
			require(
				ok,
				ufmt.Sprintf(
					"[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uint64(-amount1))(%d) failed",
					pool.token1Path, recipient.String(), amount1.Abs().Uint64(),
				),
			)
			pool.balances.token1.AddInt(pool.balances.token1, amount1)
		}
	} else {
		// payer > pool
		balance1Before := balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token1Path, payer, consts.POOL_ADDR, uint64(amount1.Int64()))
		require(
			ok,
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token1Path(%s), payer(%s), consts.POOL_ADDR(%s), uint64(amount1))(%d) failed",
				pool.token1Path, payer.String(), consts.POOL_ADDR.String(), uint64(amount1.Int64()),
			),
		)

		require(
			new(u256.Int).Add(u256.NewUint(balance1Before).Int(), amount1).Lte(u256.NewUint(balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())).Int()),
			ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)",
				balance1Before, amount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr()),
			),
		)
		pool.balances.token1.AddInt(pool.balances.token1, amount1)

		if amount0.IsNeg() { // pool > recipient
			require(pool.balances.token0.Gt(amount0.Abs()), ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) > -amount0(%d)", pool.balances.token0, amount0.Neg()))

			ok := transferByRegisterCall(pool.token0Path, recipient, amount0.Abs().Uint64())
			require(
				ok,
				ufmt.Sprintf(
					"[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uint64(-amount0))(%d) failed",
					pool.token0Path, recipient.String(), amount0.Abs().Uint64(),
				),
			)
			pool.balances.token0.AddInt(pool.balances.token0, amount0)
		}
	}

	pool.slot0.unlocked = true

	return resAmount0.Bigint(), resAmount1.Bigint()
}

// ADMIN
func SetFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	require(isAdmin(PrevRealmAddr()), ufmt.Sprintf("[POOL] pool.gno__SetFeeProtocol() || caller(%s) must be admin", PrevRealmAddr()))

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
	g.SetGovParameter("protocoL_fees", feeProtocol0+(feeProtocol1<<4))
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

	amount0 := amount0Requested.Min(pool.protocolFees.token0)
	amount1 := amount1Requested.Min(pool.protocolFees.token1)

	// after
	amount0, amount1 = pool.saveProtocolFees(amount0.Clone(), amount1.Clone())

	ok := transferByRegisterCall(pool.token0Path, recipient, uint64(amount0.Uint64()))
	require(
		ok,
		ufmt.Sprintf(
			"[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uint64(amount0))(%d) failed",
			pool.token0Path, recipient.String(), uint64(amount0.Uint64()),
		),
	)

	ok = transferByRegisterCall(pool.token1Path, recipient, uint64(amount1.Uint64()))
	require(
		ok,
		ufmt.Sprintf(
			"[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uint64(amount1))(%d) failed",
			pool.token1Path, recipient.String(), uint64(amount1.Uint64()),
		),
	)

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
	// println("MODI_position.tokensOwed0", position.tokensOwed0.Dec())
	// println("MODI_position.tokensOwed1", position.tokensOwed1.Dec())
	// println()

	amount0 := u256.Zero().Int()
	amount1 := u256.Zero().Int()

	if !params.liquidityDelta.IsZero() {
		if pool.slot0.tick < params.tickLower {
			amount0 = sqrtPriceMathGetAmount0Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta.Clone(),
			)
		} else if pool.slot0.tick < params.tickUpper {
			liquidityBefore := pool.liquidity

			amount0 = sqrtPriceMathGetAmount0Delta(
				pool.slot0.sqrtPriceX96,
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta.Clone(),
			)

			amount1 = sqrtPriceMathGetAmount1Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPriceX96,
				params.liquidityDelta.Clone(),
			)

			pool.liquidity = liquidityMathAddDelta(liquidityBefore, params.liquidityDelta.Clone())

		} else {
			amount1 = sqrtPriceMathGetAmount1Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta.Clone(),
			)
		}
	}

	return position, amount0, amount1
}

func (pool *Pool) updatePosition(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
	_liquidityDelta *u256.Int,
	tick int32,
) PositionInfo {
	// println(">> liquidityDelta", _liquidityDelta.Dec())
	// println(">> tick:", tick)
	liquidityDelta := _liquidityDelta.Clone()

	var _feeGrowthGlobal0X128 *u256.Uint = pool.feeGrowthGlobal0X128
	var _feeGrowthGlobal1X128 *u256.Uint = pool.feeGrowthGlobal1X128

	var flippedLower, flippedUpper bool

	if !liquidityDelta.IsZero() {
		// println("tickLower", tickLower)
		// println("tick", tick)
		// println("liquidityDelta", liquidityDelta.Dec())
		// println("_feeGrowthGlobal0X128", _feeGrowthGlobal0X128.Dec())
		// println("_feeGrowthGlobal1X128", _feeGrowthGlobal1X128.Dec())
		// println("pool.maxLiquidityPerTick", pool.maxLiquidityPerTick.Dec())
		flippedLower = pool.tickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			pool.maxLiquidityPerTick,
		)

		// println("tickUpper", tickUpper)
		// println("tick", tick)
		// println("liquidityDelta", liquidityDelta.Dec())
		// println("_feeGrowthGlobal0X128", _feeGrowthGlobal0X128.Dec())
		// println("_feeGrowthGlobal1X128", _feeGrowthGlobal1X128.Dec())
		// println("pool.maxLiquidityPerTick", pool.maxLiquidityPerTick.Dec())
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
			// println("3")
			// println("tickLower:", tickLower)
			// println("pool.tickSpacing:", pool.tickSpacing)
			pool.tickBitmapFlipTick(tickLower, pool.tickSpacing)
		}

		if flippedUpper {
			// println("4")
			pool.tickBitmapFlipTick(tickUpper, pool.tickSpacing)
		}
	}
	// NO LIQ, ONLY BURN 0

	// println("tickLower", tickLower)
	// println("tickUpper", tickUpper)
	// println("tick", tick)
	// println("_feeGrowthGlobal0X128", _feeGrowthGlobal0X128.Dec())
	// println("_feeGrowthGlobal1X128", _feeGrowthGlobal1X128.Dec())
	feeGrowthInside0X128, feeGrowthInside1X128 := pool.tickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	positionKey := positionGetKey(owner, tickLower, tickUpper)

	// println("positionKey", positionKey)
	// println("liquidityDelta", liquidityDelta.Dec())
	// println("feeGrowthInside0X128", feeGrowthInside0X128.Dec()) // XXX
	// println("feeGrowthInside1X128", feeGrowthInside1X128.Dec())
	position := pool.positionUpdateWithKey(
		positionKey,
		liquidityDelta,
		feeGrowthInside0X128,
		feeGrowthInside1X128,
	)
	// println(">> position.tokensOwed0", position.tokensOwed0.Dec())

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
		amount0.Sub(amount0, u256.One())
	}

	if !amount1.IsZero() && amount1.Eq(pool.protocolFees.token1) {
		amount1.Sub(amount1, u256.One())
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
