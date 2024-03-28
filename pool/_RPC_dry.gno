package pool

import (
	"std"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/demo/int256"
	u256 "gno.land/p/demo/uint256"
)

// DrySwap simulates a swap and returns the amount0, amount1 that would be received and a boolean indicating if the swap is possible
func DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	zeroForOne bool,
	_amountSpecified string, // int256
	_sqrtPriceLimitX96 string, // uint160
) (string, string, bool) {

	if _amountSpecified == "0" {
		return "0", "0", false
	}

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	sqrtPriceLimitX96 := u256.MustFromDecimal(_sqrtPriceLimitX96)

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0

	if zeroForOne {
		min_sqrt_ratio := u256.MustFromDecimal(consts.MIN_SQRT_RATIO)
		cond1 := sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Gt(min_sqrt_ratio)

		if !(cond1 && cond2) {
			return "0", "0", false
		}
	} else {
		max_sqrt_ratio := u256.MustFromDecimal(consts.MAX_SQRT_RATIO)
		cond1 := sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96)
		cond2 := sqrtPriceLimitX96.Lt(max_sqrt_ratio)

		if !(cond1 && cond2) {
			return "0", "0", false
		}
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

	exactInput := amountSpecified.Gt(i256.Zero())

	var state SwapState
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

		// get the price for the next tick
		step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)

		isLower := step.sqrtPriceNextX96.Lt(sqrtPriceLimitX96)
		isHigher := step.sqrtPriceNextX96.Gt(sqrtPriceLimitX96)

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
			uint64(pool.fee),
		)

		amountInWithFee := i256.FromUint256(new(u256.Uint).Add(step.amountIn, step.feeAmount))
		if exactInput {
			state.amountSpecifiedRemaining = i256.Zero().Sub(state.amountSpecifiedRemaining, amountInWithFee)
			state.amountCalculated = i256.Zero().Sub(state.amountCalculated, i256.FromUint256(step.amountOut))
		} else {
			state.amountSpecifiedRemaining = i256.Zero().Add(state.amountSpecifiedRemaining, i256.FromUint256(step.amountOut))
			state.amountCalculated = i256.Zero().Add(state.amountCalculated, amountInWithFee)
		}

		// if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
		if cache.feeProtocol > 0 {
			delta := new(u256.Uint).Div(step.feeAmount, u256.NewUint(uint64(cache.feeProtocol)))
			step.feeAmount = new(u256.Uint).Sub(step.feeAmount, delta)
			state.protocolFee = new(u256.Uint).Add(state.protocolFee, delta)
		}

		// update global fee tracker
		if state.liquidity.Gt(u256.Zero()) {
			_q128 := u256.MustFromDecimal(consts.Q128)

			value1 := new(u256.Uint).Mul(step.feeAmount, _q128)
			value2 := new(u256.Uint).Div(value1, state.liquidity)

			// r3v4_xxx: if drySwap update this, next swap gets affect in test cases
			// state.feeGrowthGlobalX128 = new(u256.Uint).Add(state.feeGrowthGlobalX128, value2)
		}

		// shift tick if we reached the next price
		if state.sqrtPriceX96.Eq(step.sqrtPriceNextX96) {
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
					liquidityNet = i256.Zero().Neg(liquidityNet)
				}

				state.liquidity = liquidityMathAddDelta(state.liquidity, liquidityNet)
			}

			if zeroForOne {
				state.tick = step.tickNext - 1
			} else {
				state.tick = step.tickNext
			}
		} else if !(state.sqrtPriceX96.Eq(step.sqrtPriceStartX96)) {
			// recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
			state.tick = common.TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
		}
	}
	// END LOOP

	var amount0, amount1 *i256.Int
	if zeroForOne == exactInput {
		amount0 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = i256.Zero().Sub(amountSpecified, state.amountSpecifiedRemaining)
	}

	if zeroForOne {
		if pool.balances.token1.Lt(amount1.Abs()) {
			// NOT ENOUGH BALANCE for output token1
			return "0", "0", false
		}
	} else {
		if pool.balances.token0.Lt(amount0.Abs()) {
			// NOT ENOUGH BALANCE for output token0
			return "0", "0", false
		}
	}

	// JUST NOT ENOUGH BALANCE
	if amount0.IsZero() || amount1.IsZero() {
		return "0", "0", false
	}

	pool.slot0.unlocked = true
	return amount0.ToString(), amount1.ToString(), true
}
