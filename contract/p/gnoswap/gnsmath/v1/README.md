# gnsmath

Core mathematical operations for GnoSwap's concentrated liquidity AMM.

## Overview

This package provides the fundamental calculations for concentrated liquidity, including tick conversion, liquidity math calculations, sqrt price math, swap calculations, and bit manipulation utilities. Operations use Q64.96, Q128.128, and Q160 fixed-point representations where appropriate.

The implementation follows Uniswap V3's mathematical model, ensuring compatibility and correctness for cross-chain liquidity operations.

## Features

- **Bit Math**: MSB/LSB calculations for tick bitmap operations
- **Tick Math**: Tick and Q64.96 sqrt-price conversions
- **Liquidity Math**: Liquidity and token amount conversions for price ranges
- **Sqrt Price Math**: Token amount conversions using Q64.96 format
- **Swap Math**: Single-step swap calculations with fee handling
- **Overflow Protection**: Built-in int256 overflow detection
- **Rounding Control**: Configurable rounding for AMM safety

## Core Concepts

### Q96 Fixed-Point Format

Square root prices use Q64.96 representation:
- `sqrtPriceX96 = sqrt(token1/token0) * 2^96`
- Enables precise integer arithmetic without floating-point

### Rounding Directions

- **Round UP**: Amounts owed TO pool (deposits, exact input)
- **Round DOWN**: Amounts owed FROM pool (withdrawals, exact output)

## Usage

```go
package main

import (
    "gno.land/p/gnoswap/gnsmath/v1"
    i256 "gno.land/p/gnoswap/int256/v1"
    u256 "gno.land/p/gnoswap/uint256/v1"
)

func main() {
    // Calculate token amounts for a signed liquidity change.
    sqrtPriceA := u256.MustFromDecimal("79228162514264337593543950336")
    sqrtPriceB := u256.MustFromDecimal("79625275426524748796330556128")
    liquidityDelta := i256.MustFromDecimal("1000000000000000000")
    amount0 := gnsmath.GetAmount0Delta(sqrtPriceA, sqrtPriceB, liquidityDelta)
    amount1 := gnsmath.GetAmount1Delta(sqrtPriceA, sqrtPriceB, liquidityDelta)
    println(amount0.ToString(), amount1.ToString())

    // Q64.96 prices and a positive amount remaining select exact input.
    feePips := uint64(3000) // 0.3%
    currentPrice := u256.MustFromDecimal("79228162514264337593543950336")
    targetPrice := u256.MustFromDecimal("158456325028528675187087900672")
    liquidity := u256.MustFromDecimal("1000000000000000000")
    amountRemaining := i256.MustFromDecimal("1000000")
    sqrtPriceNext, amountIn, amountOut, feeAmount := gnsmath.SwapMathComputeSwapStep(
        currentPrice, targetPrice, liquidity, amountRemaining, feePips,
    )
    println(sqrtPriceNext.ToString(), amountIn.ToString(), amountOut.ToString(), feeAmount.ToString())

    tickBitmap := u256.NewUint(0xFF00)
    println(gnsmath.BitMathMostSignificantBit(tickBitmap)) // 15
    println(gnsmath.BitMathLeastSignificantBit(tickBitmap)) // 8
}
```

## API

### Bit Math

- `BitMathMostSignificantBit(x *u256.Uint) uint8` - Find MSB position (0-255)
- `BitMathLeastSignificantBit(x *u256.Uint) uint8` - Find LSB position (0-255)

### Tick Math

- `TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint` - Convert tick to Q64.96 sqrt price
- `TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32` - Convert a Q64.96 sqrt price to tick; accepts `[MinSqrtRatio, MaxSqrtRatio)`

### Liquidity Math

- `GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) *u256.Uint`
  - Calculate max liquidity from token amounts and price range
- `GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (*u256.Uint, *u256.Uint)`
  - Calculate token amounts represented by liquidity and price range
- `LiquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint`
  - Apply signed liquidity delta; the result is bounded by `MaxUint128` and panics if it exceeds that bound

### Sqrt Price Math

- `GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int`
  - Calculate token0 amount as `liquidity * (1/√Pa - 1/√Pb)` after ordering the ratios; Q64.96 scaling and rounding are applied
- `GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) *i256.Int`
  - Calculate token1 amount as `liquidity * (√Pb - √Pa) / 2^96` after ordering the ratios; rounding depends on the sign of liquidity

### Swap Math

- `SwapMathComputeSwapStep(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity *u256.Uint, amountRemaining *i256.Int, feePips uint64) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint)`
  - Returns: (nextSqrtPrice, amountIn, amountOut, feeAmount)
  - Handles both exact input and exact output swaps
