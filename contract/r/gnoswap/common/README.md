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

## Tick Math Functions

### TickMathGetSqrtRatioAtTick

Converts a tick index to square root price ratio in Q64.96 format. Based on the formula: `sqrtPriceX96 = sqrt(1.0001^tick) * 2^96`

Uses bit manipulation and pre-computed constants for gas efficiency, exactly matching Uniswap V3's implementation.

### TickMathGetTickAtSqrtRatio

Converts a square root price ratio back to its tick index. Returns the greatest tick where `getSqrtRatioAtTick(tick) <= ratio`.

Uses logarithmic calculation with fixed-point arithmetic to find the appropriate tick for a given price.

## Liquidity Math Functions

### GetLiquidityForAmounts

Calculates the maximum liquidity that can be minted given token amounts and a price range. Returns the lesser of liquidity based on token0 or token1 to ensure the pool remains balanced.

### GetAmountsForLiquidity

Calculates the required token amounts to achieve a specified liquidity within a price range. Returns amounts as strings for precision.

### LiquidityMathAddDelta

Applies a liquidity delta (positive or negative) to current liquidity, with overflow/underflow protection.

## GRC20 Registry Helpers

### Token Operations

- **GetToken**: Retrieves GRC20 token instance (panics if not registered)
- **GetTokenTeller**: Gets teller interface for token operations
- **IsRegistered**: Checks if token is registered in grc20reg
- **MustRegistered**: Validates multiple tokens are registered

### Token Queries

- **TotalSupply**: Returns total supply of a token
- **BalanceOf**: Returns token balance for an address
- **Allowance**: Returns allowance from owner to spender

### Token Transfers (with error handling)

- **Transfer**: Transfers tokens to address, returns error on failure
- **TransferFrom**: Transfers tokens from one address to another, returns error on failure
- **Approve**: Approves spender to use tokens, returns error on failure

### Safe Transfer Functions

- **SafeGRC20Transfer**: Transfers tokens, panics on failure
- **SafeGRC20TransferFrom**: Transfers from address, panics on failure
- **SafeGRC20Approve**: Approves tokens, panics on failure

## Coin Utilities

### GNOT Path Checks

- **IsGNOTPath**: Checks if path is native or wrapped ugnot
- **IsGNOTNativePath**: Checks for native GNOT path ("ugnot")
- **IsGNOTWrappedPath**: Checks for wrapped ugnot path (wugnot)

### Coin Validation and Assertion Functions

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
- **Q96_RESOLUTION**: 96 bits
- **Q128_RESOLUTION**: 128 bits

## Error Handling

The package defines several error codes with [GNOSWAP-COMMON-XXX] prefixes:

- **001**: Value out of range
- **002**: Token is not registered
- **003**: Invalid input data
- **004**: Overflow
- **005**: Identical ticks
- **006**: Sent coins contain unsupported coins
- **007**: Sent GNOT amount does not match specified amount
- **008**: Handle native coin is not allowed

## Usage Examples

### Example 1: Calculate Liquidity for Token Amounts

```go
import (
    "gno.land/r/gnoswap/common"
    u256 "gno.land/p/gnoswap/uint256"
)

func AddLiquidity(amount0, amount1 string, tickLower, tickUpper int32) {
    // Get current pool price
    sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336") // 1.0

    // Convert ticks to sqrt ratios
    sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(tickLower)
    sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(tickUpper)

    // Calculate liquidity
    liquidity := common.GetLiquidityForAmounts(
        sqrtPriceX96,
        sqrtRatioAX96,
        sqrtRatioBX96,
        u256.MustFromDecimal(amount0),
        u256.MustFromDecimal(amount1),
    )
}
```

### Example 2: Convert Price to Tick

```go
func GetTickFromPrice(price float64) int32 {
    // Convert price to sqrt ratio in Q64.96 format
    sqrtPriceX96 := calculateSqrtRatioX96(price)

    // Get tick for this price
    tick := common.TickMathGetTickAtSqrtRatio(sqrtPriceX96)

    return tick
}
```

### Example 3: Safe GRC20 Token Transfer

```go
func TransferTokens(tokenPath string, to address, amount int64) {
    // Validate token is registered
    common.MustRegistered(tokenPath)

    // Safe transfer (panics on failure)
    common.SafeGRC20Transfer(cur, tokenPath, to, amount)
}
```

### Example 4: Validate GNOT Payment

```go
func ProcessGNOTPayment(expectedAmount int64) {
    // Validate user sent correct GNOT amount
    common.AssertIsUserSendGNOTAmount(expectedAmount)

    // Process payment
    processPayment(expectedAmount)
}
```

## Best Practices

1. **Tick Validation**: Always ensure ticks are within valid range [-887272, 887272]
2. **Precision**: Use u256.Uint for all calculations to avoid precision loss
3. **Safe Transfers**: Prefer SafeGRC20* functions to handle transfer failures
4. **Token Registration**: Always check token registration before operations
5. **GNOT Handling**: Use assertion functions for native coin validation
6. **Clone Values**: Clone u256.Uint values before passing to functions to prevent mutation

## Mathematical Accuracy

All mathematical functions in this package are designed to match Uniswap V3's implementation exactly, ensuring:

- Identical tick-to-price conversions
- Consistent liquidity calculations
- Proper rounding behavior
- Overflow/underflow protection

## Performance Optimizations

The package includes several optimizations:

- Pre-computed constants for tick math
- Bit manipulation for efficient calculations
- MSB lookup tables for logarithm calculations
- Reusable temporary variables to reduce allocations

Package common is essential for all GnoSwap protocol contracts requiring price calculations, liquidity management, or token operations.
