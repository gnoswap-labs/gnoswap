package pool

import (
	"std"

	"gno.land/p/demo/common"
	"gno.land/p/demo/u256"

	"gno.land/r/demo/consts"
)

func DrySwap(
	token0Path string,
	token1Path string,
	pFee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified_ bigint,
	sqrtPriceLimitX96_ bigint,
) (bigint, bigint, bool) {

	if amountSpecified_ == 0 {
		return 0, 0, false
	}

	pool := GetPool(token0Path, token1Path, pFee)
	slot0Start := pool.slot0

	amountSpecified := u256.IntFromBigint(amountSpecified_)
	sqrtPriceLimitX96 := u256.FromDecimal(string(sqrtPriceLimitX96_))

	if zeroForOne {
		if !(sqrtPriceLimitX96.Lt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Gt(u256.FromBigint(consts.MIN_SQRT_RATIO))) {
			return 0, 0, false
		}
	} else {
		if !(sqrtPriceLimitX96.Gt(slot0Start.sqrtPriceX96) && sqrtPriceLimitX96.Lt(u256.FromBigint(consts.MAX_SQRT_RATIO))) {
			return 0, 0, false
		}
	}

	slot0Start.unlocked = false

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
		if !(pool.balances.token1.Gte(amount1.Abs())) {
			// NOT ENOUGH BALANCE for output token1
			return 0, 0, false
		}

	} else {
		if !(pool.balances.token0.Gte(amount0.Abs())) {
			// NOT ENOUGH BALANCE for output token0
			return 0, 0, false
		}
	}

	// just not enough balance
	if amount0.IsZero() && amount1.IsZero() {
		return 0, 0, false
	}

	return resAmount0.Bigint(), resAmount1.Bigint(), true
}
