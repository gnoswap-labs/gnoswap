// Package gnsmath provides core mathematical operations for GnoSwap's concentrated liquidity AMM.
//
// ## Overview
//
// This package provides the fundamental calculations for concentrated liquidity,
// including sqrt price math, swap calculations, and bit manipulation utilities.
// All operations use Q96 and Q160 fixed-point arithmetic for precision.
//
// The implementation follows Uniswap V3's mathematical model, ensuring
// compatibility and correctness for cross-chain liquidity operations.
//
// ## Features
//
//   - Bit Math: MSB/LSB calculations for tick bitmap operations
//   - Sqrt Price Math: Token amount conversions using Q64.96 format
//   - Swap Math: Single-step swap calculations with fee handling
//   - Overflow Protection: Built-in int256 overflow detection
//   - Rounding Control: Configurable rounding for AMM safety
//
// ## Core Concepts
//
// ### Q96 Fixed-Point Format
//
// Square root prices use Q64.96 representation:
//   - sqrtPriceX96 = sqrt(token1/token0) * 2^96
//   - Enables precise integer arithmetic without floating-point
//
// ### Rounding Directions
//
//   - Round UP: Amounts owed TO pool (deposits, exact input)
//   - Round DOWN: Amounts owed FROM pool (withdrawals, exact output)
//
// ## Usage
//
//	import (
//	    "gno.land/p/gnoswap/gnsmath"
//	    i256 "gno.land/p/gnoswap/int256"
//	    u256 "gno.land/p/gnoswap/uint256"
//	)
//
//	// Calculate token amounts for liquidity change
//	sqrtPriceA := u256.MustFromDecimal("79228162514264337593543950336")
//	sqrtPriceB := u256.MustFromDecimal("79625275426524748796330556128")
//	liquidity := i256.MustFromDecimal("1000000000000000000")
//
//	amount0 := gnsmath.GetAmount0Delta(sqrtPriceA, sqrtPriceB, liquidity)
//	amount1 := gnsmath.GetAmount1Delta(sqrtPriceA, sqrtPriceB, liquidity)
//
//	// Compute swap step
//	feePips := uint64(3000) // 0.3% fee
//	sqrtPriceNext, amountIn, amountOut, feeAmount := gnsmath.SwapMathComputeSwapStep(
//	    currentPrice,
//	    targetPrice,
//	    liquidity,
//	    amountRemaining,
//	    feePips,
//	)
//
//	// Bit operations for tick bitmap
//	tickBitmap := u256.NewUint(0xFF00)
//	msb := gnsmath.BitMathMostSignificantBit(tickBitmap)
// println(msg) // Output: 15
//
//	lsb := gnsmath.BitMathLeastSignificantBit(tickBitmap)
// println(lsb) // Output: 8
//
// ## API
//
// ### Bit Math
//
//   - BitMathMostSignificantBit(x *u256.Uint) uint8 - Find MSB position (0-255)
//   - BitMathLeastSignificantBit(x *u256.Uint) uint8 - Find LSB position (0-255)
//
// ### Sqrt Price Math
//
//   - GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int
//     Calculate token0 amount: liquidity * (1/√Pb - 1/√Pa)
//   - GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int
//     Calculate token1 amount: liquidity * (√Pb - √Pa)
//
// ### Swap Math
//
//   - SwapMathComputeSwapStep(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity *u256.Uint, amountRemaining *i256.Int, feePips uint64) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint)
//     Returns: (nextSqrtPrice, amountIn, amountOut, feeAmount)
//     Handles both exact input and exact output swaps
package gnsmath
