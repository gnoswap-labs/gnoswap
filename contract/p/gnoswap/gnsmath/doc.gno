// Package gnsmath provides core mathematical operations for GnoSwap's concentrated liquidity AMM.
//
// ## Overview
//
// This package provides the fundamental calculations for concentrated liquidity,
// including tick conversion, liquidity math calculations, sqrt price math, swap
// calculations, and bit manipulation utilities. All operations use Q64.96,
// Q128.128, and Q160 fixed-point arithmetic where appropriate.
//
// The implementation follows Uniswap V3's mathematical model.
//
// ## Features
//
//   - Bit Math: MSB/LSB calculations for tick bitmap operations
//   - Tick Math: tick and Q64.96 sqrt-price conversions
//   - Liquidity Math: liquidity and token amount math for price ranges
//   - Sqrt Price Math: token amount conversions using Q64.96 format
//   - Swap Math: single-step swap calculations with fee handling
//   - Overflow Protection: explicit int256/uint256 overflow checks
//   - Rounding Control: configurable rounding for AMM safety
//
// ## Core Concepts
//
// ### Q64.96 Fixed-Point Format
//
// Square root prices use Q64.96 representation:
//   - sqrtPriceX96 = sqrt(token1/token0) * 2^96
//   - Enables precise integer arithmetic without floating-point
//
// ### Rounding Directions
//
//   - Round UP: amounts owed TO pool (deposits, exact input)
//   - Round DOWN: amounts owed FROM pool (withdrawals, exact output)
//
// ## API
//
// ### Bit Math
//
//   - BitMathMostSignificantBit(x *u256.Uint) uint8
//   - BitMathLeastSignificantBit(x *u256.Uint) uint8
//
// ### Tick Math
//
//   - TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint
//   - TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32
//
// ### Liquidity Math
//
//   - GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) *u256.Uint
//   - GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (*u256.Uint, *u256.Uint)
//   - LiquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint
//
// ### Sqrt Price Math
//
//   - GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int
//   - GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int
//
// ### Swap Math
//
//   - SwapMathComputeSwapStep(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity *u256.Uint, amountRemaining *i256.Int, feePips uint64) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint)
package gnsmath
