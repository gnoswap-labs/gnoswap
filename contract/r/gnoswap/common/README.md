# Common Package

Package common provides shared utilities and mathematical functions for GnoSwap protocol contracts.

## Overview

The common package contains essential mathematical functions, helper utilities, and shared logic used across the GnoSwap protocol. It provides implementations for concentrated liquidity calculations, price/tick conversions, GRC20 token operations, and native coin handling.

This package serves as the mathematical foundation for the protocol, implementing algorithms based on Uniswap V3's concentrated liquidity model with Q64.96 fixed-point arithmetic.

## Key Components

1. **Tick Math**: Price-tick conversion functions for concentrated liquidity positions
2. **Liquidity Math**: Liquidity calculations based on token amounts and price ranges
3. **GRC20 Registry Helpers**: Convenient wrappers for GRC20 token operations
4. **Coin Utilities**: Native coin (GNOT) handling and validation
5. **Assertion Utilities**: Input validation and authorization checks

## Core Concepts

### Ticks and Price

Ticks are logarithmic representations of prices in the concentrated liquidity model:

- Each tick represents a 0.01% (1 basis point) price change
- Formula: `price = 1.0001^tick`
- Valid tick range: `[-887272, 887272]`
- Prices are stored as square root ratios in Q64.96 fixed-point format

### Q64.96 Fixed-Point Format

Square root prices are represented in Q64.96 format:

- 64 bits for integer part, 96 bits for fractional part
- Represents: `sqrtPriceX96 = sqrt(token1/token0) * 2^96`
- Allows precise price calculations without floating-point arithmetic

### Liquidity

Liquidity (L) represents the relationship between token amounts and price:

- For token0: `amount0 = L * (1/√P_b - 1/√P_a)`
- For token1: `amount1 = L * (√P_b - √P_a)`
- Where P_a and P_b are lower and upper price bounds

## API Reference

### Tick Math Functions

- **TickMathGetSqrtRatioAtTick**: Converts tick to sqrt price ratio (Q64.96)
- **TickMathGetTickAtSqrtRatio**: Converts sqrt price ratio to tick

### Liquidity Math Functions

- **GetLiquidityForAmounts**: Calculates max liquidity from token amounts and price range
- **GetAmountsForLiquidity**: Calculates required token amounts for specified liquidity
- **LiquidityMathAddDelta**: Applies liquidity delta with overflow protection

### GRC20 Registry Helpers

**Token Operations:**
- **GetToken**: Retrieves GRC20 token instance
- **GetTokenTeller**: Gets teller interface for token operations
- **IsRegistered**: Checks token registration status
- **MustRegistered**: Validates multiple tokens are registered

**Token Queries:**
- **TotalSupply**: Returns total supply of a token
- **BalanceOf**: Returns token balance for an address
- **Allowance**: Returns allowance from owner to spender

**Token Transfers:**
- **Transfer/TransferFrom/Approve**: Returns error on failure
- **SafeGRC20Transfer/SafeGRC20TransferFrom/SafeGRC20Approve**: Panics on failure

### Coin Utilities

**GNOT Path Checks:**
- **IsGNOTPath**: Checks if path is native or wrapped ugnot
- **IsGNOTNativePath**: Checks for native GNOT path
- **IsGNOTWrappedPath**: Checks for wrapped ugnot path

**Coin Validation:**
- **ExistsUserSendCoins**: Checks if user sent any coins
- **AssertIsUserSendGNOTAmount**: Validates GNOT amount or panics
- **AssertIsNotHandleNativeCoin**: Ensures no native coins in transaction

## Constants

### Tick Bounds

- **minTick**: -887272 (minimum valid tick)
- **maxTick**: 887272 (maximum valid tick)

### GNOT Paths

- **GNOT_DENOM**: "ugnot" (native denomination)
- **WUGNOT_PATH**: "gno.land/r/gnoland/wugnot" (wrapped ugnot path)

### Fixed-Point Constants

- **Q96**: 2^96 (79228162514264337593543950336)
- **MAX_UINT128**: 2^128 - 1

