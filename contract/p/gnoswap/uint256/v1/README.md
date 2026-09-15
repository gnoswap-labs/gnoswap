# uint256

256-bit unsigned integer arithmetic for GnoSwap.

## Overview

Fixed-size 256-bit unsigned integer library optimized for AMM calculations with
precise `MulDiv` operations. The unsuffixed `Add`, `Sub`, and `Mul` methods
return the low 256 bits; the corresponding `AddOverflow`, `SubOverflow`, and
`MulOverflow` variants also report an overflow/underflow flag.

## Features

- Fixed 256-bit size (4 uint64 values)
- Explicit overflow detection via `*Overflow` variants
- Optimized `MulDiv` for precise calculations
- Decimal string conversion
- Range: 0 to 2^256-1

## Usage

```go
package main

import u256 "gno.land/p/gnoswap/uint256/v1"

func main() {
    a := u256.NewUint(1000)
    b := u256.MustFromDecimal("1000000000000000000")
    result, overflow := new(u256.Uint).AddOverflow(a, b)
    if overflow {
        panic("unsigned addition overflow")
    }
    println(result.ToString()) // 1000000000000001000

    // MulDiv calculates floor(a*b/c). The denominator must be non-zero,
    // and the quotient must fit in 256 bits; otherwise it panics.
    c := u256.NewUint(3)
    println(u256.MulDiv(a, b, c).ToString()) // 333333333333333333333
}
```

## Credits

Ported from [holiman/uint256](https://github.com/holiman/uint256)