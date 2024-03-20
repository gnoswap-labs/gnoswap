package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	gv "gno.land/r/demo/gov"

	i256 "gno.land/p/demo/big/int256"
	u256 "gno.land/p/demo/big/uint256"
)

// Mint creates a new position and mints liquidity tokens then return amount0, amount1 in string
//
// Panics if any of the following conditions are met:
// - The caller is user
// - Caller does not have enough token0 or token1
func Mint(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient string,
	tickLower int32,
	tickUpper int32,
	_liquidityAmount string, // uint128
) (string, string) { // uint256 x2
	common.DisallowCallFromUser()
	common.AllowCallFromOnly(consts.POSITION_PATH)

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)

	pool := GetPool(token0Path, token1Path, fee)
	_, amount0, amount1 := pool.modifyPosition( // int256 x2
		ModifyPositionParams{
			std.Address(recipient),            // owner
			tickLower,                         // tickLower
			tickUpper,                         // tickUpper
			i256.FromUint256(liquidityAmount), // liquidityDelta
		},
	)

	if amount0.Gt(i256.Zero()) {
		balance0Before := balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())

		from := std.GetOrigCaller() // token should be transferred from actual user(std.GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token0Path, from, to, amount0.Uint64())
		if !ok {
			panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token0Path(%s), from(%s), to(%s), amount0.Uint64())(%d) failed", pool.token0Path, from.String(), to.String(), amount0.Uint64()))
		}

		// pool token0 balance should be increased exactly as much amount0
		if !(balance0Before+amount0.Uint64() <= balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || balance0Before(%d) + amount0(%d) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)", balance0Before, amount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())))
		}
	}

	if amount1.Gt(i256.Zero()) {
		balance1Before := balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())

		from := std.GetOrigCaller() // token should be transferred from actual user(std.GetOrigCaller), not from the realm(PrevRealm)
		to := GetOrigPkgAddr()

		ok := transferFromByRegisterCall(pool.token1Path, from, to, amount1.Uint64())
		if !ok {
			panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || transferFromByRegisterCall(pool.token1Path(%s), from(%s), to(%s), amount1.Uint64())(%d) failed", pool.token1Path, from.String(), to.String(), amount1.Uint64()))
		}

		// pool token1 balance should be increased exactly as much amount1
		if !(balance1Before+amount1.Uint64() <= balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Mint() || balance1Before(%d) + amount1(%d) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)", balance1Before, amount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())))
		}
	}

	pool.balances.token0 = new(u256.Uint).Add(pool.balances.token0, amount0.Abs())
	pool.balances.token1 = new(u256.Uint).Add(pool.balances.token1, amount1.Abs())

	return amount0.ToString(), amount1.ToString()
}

// Burn removes liquidity from the caller and account tokens owed for the liquidity to the position
// If liquidity of 0 is burned, it recalculates fees owed to a position
//
// Panics if any of the following conditions are met:
// - The caller is not the position contract
func Burn(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	_liquidityAmount string, // uint128
) (string, string) { // uint256 x2
	common.DisallowCallFromUser()
	common.AllowCallFromOnly(consts.POSITION_PATH)

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)

	pool := GetPool(token0Path, token1Path, fee)
	position, amount0Int, amount1Int := pool.modifyPosition( // in256 x2
		ModifyPositionParams{
			std.PrevRealm().Addr(), // msg.sender
			tickLower,
			tickUpper,
			i256.Zero().Neg(i256.FromUint256(liquidityAmount)),
		},
	)
	amount0 := amount0Int.Abs()
	amount1 := amount1Int.Abs()

	if amount0.Gt(u256.Zero()) || amount1.Gt(u256.Zero()) {
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, amount0)
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, amount1)
	}

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	pool.positions[positionKey] = position

	// actual token transfer happens in Collect()
	return amount0.ToString(), amount1.ToString()
}

// Collect collects tokens owed to a position
//
// Panics if any of the following conditions are met:
// - The caller is not the position contract
// - The position does not exist
func Collect(
	token0Path string,
	token1Path string,
	fee uint32,
	_recipient string,
	tickLower int32,
	tickUpper int32,
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.DisallowCallFromUser()
	common.AllowCallFromOnly(consts.POSITION_PATH)

	amount0Requested := u256.MustFromDecimal(_amount0Requested)
	amount1Requested := u256.MustFromDecimal(_amount1Requested)

	recipient := std.Address(_recipient)

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool.gno__Collect() || positionKey(%s) does not exist", positionKey))
	}

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0 := u256Min(amount0Requested, position.tokensOwed0)
	amount0 = u256Min(amount0, pool.balances.token0)

	// Update state first then transfer
	position.tokensOwed0 = new(u256.Uint).Sub(position.tokensOwed0, amount0)
	pool.balances.token0 = new(u256.Uint).Sub(pool.balances.token0, amount0)
	transferByRegisterCall(pool.token0Path, recipient, amount0.Uint64())

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1 := u256Min(amount1Requested, position.tokensOwed1)
	amount1 = u256Min(amount1, pool.balances.token1)

	// Update state first then transfer
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1)
	pool.balances.token1 = new(u256.Uint).Sub(pool.balances.token1, amount1)
	transferByRegisterCall(pool.token1Path, recipient, amount1.Uint64())

	pool.positions[positionKey] = position

	return amount0.ToString(), amount1.ToString()
}

// Swap swaps token0 for token1, or token1 for token0
//
// Panics if any of the following conditions are met:
// - The caller is not the router contract
// - Target pool is being used by another transaction
// - The amounSpecified is 0
// - The SqrtPriceLimit is not within the range
func Swap(
	token0Path string,
	token1Path string,
	fee uint32,
	_recipient string,
	zeroForOne bool,
	_amountSpecified string, // int256
	_sqrtPriceLimitX96 string, // uint160
	_payer string, // router
) (string, string) { // int256 x2
	common.DisallowCallFromUser()
	common.AllowCallFromOnly(consts.ROUTER_PATH)

	if _amountSpecified == "0" {
		panic("[POOL] pool.gno__Swap() || _amountSpecified == 0")
	}

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	sqrtPriceLimitX96 := u256.MustFromDecimal(_sqrtPriceLimitX96)

	recipient := std.Address(_recipient)
	payer := std.Address(_payer)

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0

	if !(slot0Start.unlocked) {
		panic("[POOL] pool.gno__Swap() || slot0Start.unlocked must be unlocked(true)")
	}

	var feeProtocol uint8
	var feeGrowthGlobalX128 *u256.Uint

	if zeroForOne {
		min_sqrt_ratio := u256.MustFromDecimal(consts.MIN_SQRT_RATIO)
		cond1 := sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Gt(min_sqrt_ratio)
		if !(cond1 && cond2) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > consts.MIN_SQRT_RATIO(%s)", sqrtPriceLimitX96.ToString(), slot0Start.sqrtPriceX96.ToString(), sqrtPriceLimitX96.ToString(), consts.MIN_SQRT_RATIO))
		}

		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128.Clone()
	} else {
		max_sqrt_ratio := u256.MustFromDecimal(consts.MAX_SQRT_RATIO)
		cond1 := sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Lt(max_sqrt_ratio)

		if !(cond1 && cond2) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < consts.MAX_SQRT_RATIO(%s)", sqrtPriceLimitX96.ToString(), slot0Start.sqrtPriceX96.ToString(), sqrtPriceLimitX96.ToString(), consts.MAX_SQRT_RATIO))
		}

		feeProtocol = slot0Start.feeProtocol / 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal1X128.Clone()
	}

	pool.slot0.unlocked = false

	cache := newSwapCache(sd.feeProtocol, pool.liquidity)
	state := newSwapState(pool, amountSpecified, sd.feeGrowthGlobalX128, cache.liquidityStart)

	exactInput := amountSpecified > 0
	for state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		step := executeSwapStep(pool, &state, sqrtPriceLimitX96, zeroForOne)
		applySwapStep(&state, &cache, step, exactInput)
	}

	amount0, amount1 := updatePoolState(pool, &state, &cache, &slot0Start, zeroForOne, amountSpecified, exactInput)

	if zeroForOne {
		// payer > pool for token0
		transferFrom(pool.token0Path, payer, consts.POOL_ADDR, amount0)
		pool.balances.token0 += amount0

		// pool > recipient for token1 (if amount1 is negative)
		if amount1 < 0 {
			transfer(pool.token1Path, consts.POOL_ADDR, recipient, -amount1)
			pool.balances.token1 += amount1
		}
	} else {
		// payer > pool
		transferFrom(pool.token1Path, payer, consts.POOL_ADDR, amount1)
		pool.balances.token1 += amount1

		// pool > recipient for token0 (if amount0 is negative)
		if amount0 < 0 {
			transfer(pool.token0Path, consts.POOL_ADDR, recipient, -amount0)
			pool.balances.token0 += amount0
		}
	}

	exactInput := amountSpecified.Gt(i256.Zero())

// determineSwapDirection determines the direction of the swap and initializes related parameters.
func determineSwapDirection(
	pool *Pool,
	zeroForOne bool,
	slot0 Slot0,
	sqrtPriceLimitX96 bigint,
) SwapDirection {
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         i256.Zero(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal0X128,
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         i256.Zero(),
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal1X128,
			protocolFee:              u256.Zero(),
			liquidity:                cache.liquidityStart,
		}
	}

	// continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
	for !(state.amountSpecifiedRemaining.IsZero()) && !(state.sqrtPriceX96.Eq(sqrtPriceLimitX96)) {
		var step StepComputations
		step.sqrtPriceStartX96 = state.sqrtPriceX96

	  return newSwapDirection(protocol, feeGrowth)
  }

	pool.slot0.sqrtPriceX96 = state.sqrtPriceX96
	if state.tick != slot0Start.tick {
		pool.slot0.tick = state.tick
	}

	if !(cache.liquidityStart.Eq(state.liquidity)) {
		pool.liquidity = state.liquidity
	}

	if zeroForOne {
		pool.feeGrowthGlobal0X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token0 = new(u256.Uint).Add(pool.protocolFees.token0, state.protocolFee)
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee.Gt(u256.Zero()) {
			pool.protocolFees.token1 = new(u256.Uint).Add(pool.protocolFees.token1, state.protocolFee)
		}
	}

	var amount0, amount1 *i256.Int
	if zeroForOne == exactInput {
		amount0 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
	}

	if zeroForOne {
		uAmount0 := amount0.Abs().Uint64()

		// FROM payer TO pool
		balance0Before := balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token0Path, payer, consts.POOL_ADDR, uAmount0)

		// transfer failed
		if !ok {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token0Path(%s), payer(%s), consts.POOL_ADDR(%s), uAmount0(%d)) failed", pool.token0Path, payer.String(), consts.POOL_ADDR.String(), uAmount0))
		}

		// pool token0 balance updated
		if !((balance0Before + uAmount0) <= balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())) {
			panic(ufmt.Sprintf(
				"[POOL] pool.gno__Swap() || (balance0Before(%d) + uAmount0(%d)) <= balanceOfByRegisterCall(pool.token0Path(%s), GetOrigPkgAddr()(%s))(%d)", balance0Before, uAmount0, pool.token0Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token0Path, GetOrigPkgAddr())))
		}

		pool.balances.token0 = new(u256.Uint).Add(pool.balances.token0, amount0.Abs())
		if pool.balances.token0.Lt(u256.Zero()) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) >= 0", pool.balances.token0))
		}

		// FROM pool TO recipient
		if amount1.IsNeg() {
			if pool.balances.token1.Lt(amount1.Abs()) {
				panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) >= amount1.Abs(%d)", pool.balances.token1, amount1.Abs()))
			}

			uAmount1 := amount1.Abs().Uint64()
			ok := transferByRegisterCall(pool.token1Path, recipient, uAmount1)
			if !ok {
				panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uAmount1(%d)) failed", pool.token1Path, recipient.String(), uAmount1))
			}
			pool.balances.token1 = new(u256.Uint).Sub(pool.balances.token1, amount1.Abs())
		}

		if pool.balances.token1.Lt(u256.Zero()) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) >= 0", pool.balances.token1))
		}

	} else {
		uAmount1 := amount1.Abs().Uint64()

		// FROM payer TO pool
		balance1Before := balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())
		ok := transferFromByRegisterCall(pool.token1Path, payer, consts.POOL_ADDR, uAmount1)
		if !ok {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || transferFromByRegisterCall(pool.token1Path(%s), payer(%s), consts.POOL_ADDR(%s), uAmount1(%d)) failed", pool.token1Path, payer.String(), consts.POOL_ADDR.String(), uAmount1))
		}

		if !(balance1Before+uAmount1 <= balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || (balance1Before(%d) + uAmount1(%d)) <= balanceOfByRegisterCall(pool.token1Path(%s), GetOrigPkgAddr()(%s))(%d)", balance1Before, uAmount1, pool.token1Path, GetOrigPkgAddr().String(), balanceOfByRegisterCall(pool.token1Path, GetOrigPkgAddr())))
		}

		pool.balances.token1 = new(u256.Uint).Add(pool.balances.token1, amount1.Abs())
		if pool.balances.token1.Lt(u256.Zero()) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token1(%d) >= 0", pool.balances.token1))
		}

		// FROM pool TO recipient
		if amount0.IsNeg() {
			if pool.balances.token0.Lt(amount0.Abs()) {
				panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) >= amount0.Abs(%d)", pool.balances.token0, amount0.Abs()))
			}

			uAmount0 := amount0.Abs().Uint64()
			ok := transferByRegisterCall(pool.token0Path, recipient, uAmount0)
			if !ok {
				panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uAmount0(%d)) failed", pool.token0Path, recipient.String(), uAmount0))
			}

			pool.balances.token0 = new(u256.Uint).Sub(pool.balances.token0, amount0.Abs())
		}

		if pool.balances.token0.Lt(u256.Zero()) {
			panic(ufmt.Sprintf("[POOL] pool.gno__Swap() || pool.balances.token0(%d) >= 0", pool.balances.token0))
		}
	}

	pool.slot0.unlocked = true
	return amount0.ToString(), amount1.ToString()
}

// SetFeeProtocol sets the denominator of the protocol fee
//
// Panics if any of the following conditions are met:
// - The caller is not an admin
// - The feeProtocol0 or feeProtocol1 is not in the range of 0 or 4-10
func SetFeeProtocol(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	common.MustCallFromAdmin()

	fee0Cond := (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10))
	fee1Cond := (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10))
	if !(fee0Cond && fee1Cond) {
		panic(ufmt.Sprintf("[POOL] pool.gno__SetFeeProtocol() || expected (feeProtocol0(%d) == 0 || (feeProtocol0(%d) >= 4 && feeProtocol0(%d) <= 10)) && (feeProtocol1(%d) == 0 || (feeProtocol1(%d) >= 4 && feeProtocol1(%d) <= 10))", feeProtocol0, feeProtocol0, feeProtocol0, feeProtocol1, feeProtocol1, feeProtocol1))
	}

	// iterate all pool
	for _, pool := range pools {
		pool.slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )
	}

	// update governace value
	gv.SetGovParameter("protocoL_fees", feeProtocol0+(feeProtocol1<<4))
}

// CollectProtocol collects protocol fees from the pool
//
// Panics if any of the following conditions are met:
// - The caller is not an admin
// - The recipient is the zero address
// - The amount0Requested or amount1Requested is greater than the protocol fees
func CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	_recipient string,
	_amount0Requested string, // uint128
	_amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.MustCallFromAdmin()

	recipient := std.Address(_recipient)

	amount0Requested := u256.MustFromDecimal(_amount0Requested)
	amount1Requested := u256.MustFromDecimal(_amount1Requested)

	pool := GetPool(token0Path, token1Path, fee)

	amount0 := u256Min(amount0Requested, pool.protocolFees.token0)
	amount1 := u256Min(amount1Requested, pool.protocolFees.token1)

	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)
	uAmount0 := amount0.Uint64()
	uAmount1 := amount1.Uint64()

	ok := transferByRegisterCall(pool.token0Path, recipient, uAmount0)
	if !ok {
		panic(ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token0Path(%s), recipient(%s), uAmount0)(%d) failed", pool.token0Path, recipient.String(), uAmount0))
	}

	ok = transferByRegisterCall(pool.token1Path, recipient, uAmount1)
	if !ok {
		panic(ufmt.Sprintf("[POOL] pool.gno__CollectProtocol() || transferByRegisterCall(pool.token1Path(%s), recipient(%s), uAmount1)(%d) failed", pool.token1Path, recipient.String(), uAmount1))
	}

	return amount0.ToString(), amount1.ToString()
}

func (pool *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	cond01 := amount0.Gt(u256.Zero())
	cond02 := amount0.Eq(pool.protocolFees.token0)
	if cond01 && cond02 {
		amount0 = new(u256.Uint).Sub(amount0, u256.One())
	}

	cond11 := amount1.Gt(u256.Zero())
	cond12 := amount1.Eq(pool.protocolFees.token1)
	if cond11 && cond12 {
		amount1 = new(u256.Uint).Sub(amount1, u256.One())
	}

	pool.protocolFees.token0 = new(u256.Uint).Sub(pool.protocolFees.token0, amount0)
	pool.protocolFees.token1 = new(u256.Uint).Sub(pool.protocolFees.token1, amount1)

	// return rest fee
	return amount0, amount1
}
