# uint256

256-bit unsigned integer arithmetic for GnoSwap.

## Overview

Fixed-size 256-bit unsigned integer library optimized for AMM calculations with overflow detection and precise MulDiv operations.

## Features

- Fixed 256-bit size (4 uint64 values)
- Overflow detection on all operations
- Optimized MulDiv for precise calculations
- String conversion (decimal, hex, binary)
- Range: 0 to 2^256-1

## Usage

```go
import u256 "gno.land/p/gnoswap/uint256"

// Create values
a := u256.NewUint(1000)
b := u256.MustFromDecimal("1000000000000000000")

// Arithmetic with overflow detection
result, overflow := new(u256.Uint).AddOverflow(a, b)
if overflow {
    // Handle overflow
}

// Precise MulDiv (a * b / c)
result := u256.MulDiv(a, b, c)
```

## Credits

Ported from [holiman/uint256](https://github.com/holiman/uint256)