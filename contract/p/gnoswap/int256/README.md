# int256 - Fixed-Size 256-bit Signed Integer Library

## Overview

A specialized library for 256-bit signed integer arithmetic, optimized for GnoSwap's AMM calculations. This library provides overflow-safe operations essential for DeFi protocols.

## Features

- **Fixed 256-bit size**: Predictable gas costs and behavior
- **Two's complement**: Standard signed integer representation
- **Overflow detection**: Safe arithmetic operations with overflow flags
- **AMM optimized**: Specialized functions for tick math and liquidity calculations
- **Ethereum compatible**: Follows Solidity int256 semantics

## Implementation

- Built on top of [uint256](../uint256) for underlying arithmetic
- Range: -(2^255) to 2^255-1
- All operations return overflow/underflow flags when applicable

## Usage

```go
import i256 "gno.land/p/gnoswap/int256"

// Create new int256 values
a := i256.NewInt(100)
b := i256.MustFromDecimal("-1000")

// Arithmetic with overflow detection
result, overflow := new(i256.Int).AddOverflow(a, b)
if overflow {
    // Handle overflow
}
```

## Credits

Ported from [mempooler/int256](https://github.com/mempooler/int256)
