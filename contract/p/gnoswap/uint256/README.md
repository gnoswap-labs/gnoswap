# uint256

256-bit unsigned integer arithmetic for GnoSwap. Original repository: [uint256](<https://github.com/holiman/uint256/tree/master>)

## Features

- Fixed 256-bit size (4 uint64 values)
- Overflow detection on all operations
- Optimized MulDiv for precise calculations
- String conversion (decimal, hex, binary)

## Usage

```go
import u256 "gno.land/p/gnoswap/uint256"

// Create new uint256 values
a := u256.NewUint(1000)
b := u256.MustFromDecimal("1000000000000000000") // 1e18

// Arithmetic with overflow detection
result, overflow := new(u256.Uint).AddOverflow(a, b)
if overflow {
    // Handle overflow
}

// MulDiv for precise calculations (a * b / c)
result := u256.MulDiv(a, b, c)
```

## Notes

- Range: 0 to 2^256-1
- Ported from holiman/uint256
