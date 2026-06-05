package pool

import (
	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func LiquidityMathAddDelta(lastStakedLiquidity *u256.Uint, delta *i256.Int) *u256.Uint {
	return gnsmath.LiquidityMathAddDelta(lastStakedLiquidity, delta)
}

func GetAmount0Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	return gnsmath.GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func GetAmount1Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	return gnsmath.GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	return gnsmath.TickMathGetSqrtRatioAtTick(tick)
}

func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	return gnsmath.TickMathGetTickAtSqrtRatio(sqrtPriceX96)
}

func SwapMathComputeSwapStep(
	sqrtRatioCurrentX96 *u256.Uint,
	sqrtRatioTargetX96 *u256.Uint,
	liquidity *u256.Uint,
	amountRemaining *i256.Int,
	feePips uint64,
) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint) {
	return gnsmath.SwapMathComputeSwapStep(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemaining, feePips)
}

func BitMathMostSignificantBit(x *u256.Uint) uint8 {
	return gnsmath.BitMathMostSignificantBit(x)
}

func BitMathLeastSignificantBit(x *u256.Uint) uint8 {
	return gnsmath.BitMathLeastSignificantBit(x)
}
