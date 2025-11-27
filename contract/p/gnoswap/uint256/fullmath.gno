// REF: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol

// fullmath implements Uniswap V3's FullMath library.
//
// This library provides advanced fixed-point math operations that are essential
// for Uniswap V3's tick math and liquidity calculations. It enables precise
// calculations of (a * b / denominator) with full 512-bit intermediate precision.
//
// NOTE: Unlike other arithmetic functions in the uint256 package that return errors,
// functions in this file panic on invalid inputs to maintain behavioral compatibility
// with the original Solidity implementation which uses require() statements.
//
// This design choice is intentional because:
// 1. These functions are typically used in hot paths where error handling would add overhead
// 2. Invalid inputs (like zero denominator) represent programming errors, not runtime conditions
// 3. Staying close to the Solidity implementation makes protocol porting more reliable
//
// If you need error-returning versions, wrap these functions with appropriate error handling.
package uint256

import (
	"gno.land/p/nt/ufmt"
)

// MulDiv calculates (a * b) / denominator with full 512-bit intermediate precision.
// Panics if denominator is zero or if the result overflows 256 bits.
func MulDiv(a, b, denominator *Uint) *Uint {
	if denominator.IsZero() {
		panic("denominator must be greater than 0")
	}

	// 512-bit product (8 limbs of 64 bits)
	p := umul(a, b)

	if (p[4] | p[5] | p[6] | p[7]) == 0 {
		var lo Uint
		lo.arr = [4]uint64{p[0], p[1], p[2], p[3]}
		return new(Uint).Div(&lo, denominator)
	}

	// optional early overflow check:
	// If hi >= denominator then floor((hi*2^256 + lo) / denominator) >= 2^256, which is overflow.
	{
		var hi Uint
		hi.arr = [4]uint64{p[4], p[5], p[6], p[7]}
		if denominator.Lte(&hi) {
			panic(ufmt.Sprintf("overflow: denominator(%s) must be greater than hi(%s)", denominator.ToString(), hi.ToString()))
		}
	}

	// perform 512 / 256 division
	// udivrem stores quotient into `quot` (len(u) - len(d) + 1 words)
	// we pass 8 words to be safe.
	var quot [8]uint64
	udivrem(quot[:], p[:], denominator) // ignore remainder

	if (quot[4] | quot[5] | quot[6] | quot[7]) != 0 {
		panic("uint256: MulDiv overflow (high quotient words non-zero)")
	}

	// return lower 256 bits of quotient
	var z Uint
	copy(z.arr[:], quot[:4])
	return &z
}

// MulDivRoundingUp calculates ceil((a * b) / denominator) with full 512-bit intermediate precision.
// Panics if denominator is zero or if the result overflows 256 bits.
func MulDivRoundingUp(a, b, denominator *Uint) *Uint {
	result := MulDiv(a, b, denominator)

	// Check if there's a remainder
	mulModResult := new(Uint).MulMod(a, b, denominator)

	// If there's no remainder, return the result as-is
	if mulModResult.IsZero() {
		return result
	}

	// Add 1 to round up, but check for overflow
	if result.Eq(MustFromDecimal(MAX_UINT256)) {
		panic(ufmt.Sprintf("overflow: result(%s) + 1 would exceed MAX_UINT256", result.ToString()))
	}

	return new(Uint).Add(result, one)
}

// DivRoundingUp calculates ceil(x / y) and returns the result.
// Panics if y is zero.
func DivRoundingUp(x, y *Uint) *Uint {
	if y.IsZero() {
		panic("division by zero")
	}
	div := new(Uint).Div(x, y)
	mod := new(Uint).Mod(x, y)
	z := new(Uint).Add(div, gt(mod, Zero()))
	return z
}

// gt returns One() if x > y, otherwise returns Zero().
func gt(x, y *Uint) *Uint {
	if x.Gt(y) {
		return one
	}
	return Zero()
}
