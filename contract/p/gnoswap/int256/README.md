# int256

256-bit signed integer arithmetic for GnoSwap.

## Overview

Fixed-size 256-bit signed integer library optimized for AMM calculations with overflow detection.

## Features

- Fixed 256-bit size (predictable gas costs)
- Two's complement representation
- Overflow detection on all operations
- AMM-optimized functions
- Range: -(2^255) to 2^255-1

## Usage

```go
import i256 "gno.land/p/gnoswap/int256"

// Create values
a := i256.NewInt(100)
b := i256.MustFromDecimal("-1000")

// Arithmetic with overflow detection
result, overflow := new(i256.Int).AddOverflow(a, b)
if overflow {
    // Handle overflow
}
```

## Implementation

Built on [uint256](../uint256) for underlying arithmetic.