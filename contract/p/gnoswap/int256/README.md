# int256

256-bit signed integer arithmetic for GnoSwap.

## Overview

Fixed-size 256-bit signed integer library optimized for AMM calculations.
The unsuffixed `Add`, `Sub`, and `Mul` methods return the low 256 bits
(two's-complement wrap). The `AddOverflow`, `SubOverflow`, and `MulOverflow`
variants additionally report whether the signed operation overflowed.

## Features

- Fixed 256-bit size (predictable gas costs)
- Two's complement representation
- Explicit overflow detection via `*Overflow` variants
- AMM-optimized functions
- Range: -(2^255) to 2^255-1

## Usage

```go
package main

import i256 "gno.land/p/gnoswap/int256"

func main() {
    a := i256.NewInt(100)
    b := i256.MustFromDecimal("-1000")
    result, overflow := new(i256.Int).AddOverflow(a, b)
    if overflow {
        panic("signed addition overflow")
    }
    println(result.ToString()) // -900
}
```

## Implementation

The type shares a little-endian four-word representation with `uint256` and
interoperates with it through conversion methods, but signed arithmetic is
implemented independently.