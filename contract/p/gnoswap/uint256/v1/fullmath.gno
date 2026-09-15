// REF: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol

// fullmath implements Uniswap V3's FullMath library.
//
// This library provides advanced fixed-point math operations that are essential
// for Uniswap V3's tick math and liquidity calculations. It enables precise
// calculations of (a * b / denominator) with full 512-bit intermediate precision.
//
// NOTE: Unlike the base arithmetic methods in the uint256 package, which return
// low-256-bit values (or values plus overflow flags in their `*Overflow`
// variants), functions in this file panic on invalid inputs to maintain
// behavioral compatibility with the original Solidity implementation.
//
// This design choice is intentional because:
// 1. These functions are typically used in hot paths where error handling would add overhead
// 2. Invalid inputs (like zero denominator) represent programming errors, not runtime conditions
// 3. Staying close to the Solidity implementation makes protocol porting more reliable
//
// If you need error-returning versions, wrap these functions with appropriate error handling.
package uint256

// MulDiv computes floor((a * b) / denominator) with a full 512-bit intermediate product.
//
// Parameters:
//   - a: First non-negative 256-bit multiplicand.
//   - b: Second non-negative 256-bit multiplicand.
//   - denominator: Non-zero 256-bit divisor.
//
// Returns:
//   - quotient: The exact floor quotient when it fits in 256 bits.
//
// Panics if denominator is zero or the quotient is at least 2^256.
func MulDiv(a, b, denominator *Uint) *Uint {
	if denominator.IsZero() {
		panic("denominator must be greater than 0")
	}

	// 512-bit product (8 limbs of 64 bits)
	p := umul(a, b)

	if (p[4] | p[5] | p[6] | p[7]) == 0 {
		var lo Uint
		lo[0], lo[1], lo[2], lo[3] = p[0], p[1], p[2], p[3]
		return new(Uint).Div(&lo, denominator)
	}

	// optional early overflow check:
	// If hi >= denominator then floor((hi*2^256 + lo) / denominator) >= 2^256, which is overflow.
	{
		var hi Uint
		hi[0], hi[1], hi[2], hi[3] = p[4], p[5], p[6], p[7]
		if denominator.Lte(&hi) {
			panic("overflow: denominator(" + denominator.ToString() + ") must be greater than hi(" + hi.ToString() + ")")
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
	copy(z[:], quot[:4])
	return &z
}

// MulDivRoundingUp computes ceil((a * b) / denominator) with a full 512-bit intermediate product.
//
// Parameters:
//   - a: First non-negative 256-bit multiplicand.
//   - b: Second non-negative 256-bit multiplicand.
//   - denominator: Non-zero 256-bit divisor.
//
// Returns:
//   - quotient: The ceiling quotient; it is one greater than the floor quotient
//     exactly when the product has a non-zero remainder.
//
// Panics if denominator is zero or rounding the result exceeds 256 bits.
func MulDivRoundingUp(a, b, denominator *Uint) *Uint {
	result := MulDiv(a, b, denominator)

	// Check if there's a remainder
	mulModResult := new(Uint).MulMod(a, b, denominator)

	// If there's no remainder, return the result as-is
	if mulModResult.IsZero() {
		return result
	}

	// Add 1 to round up, but check for overflow
	if result.Eq(MaxUint256()) {
		panic("overflow: result(" + result.ToString() + ") + 1 would exceed MAX_UINT256")
	}

	return result.Add(result, &Uint{1, 0, 0, 0})
}

// DivRoundingUp computes ceil(x / y) for unsigned 256-bit operands.
//
// Parameters:
//   - x: Non-negative 256-bit dividend.
//   - y: Non-zero 256-bit divisor.
//
// Returns:
//   - quotient: The quotient rounded toward positive infinity.
//
// Panics if y is zero.
func DivRoundingUp(x, y *Uint) *Uint {
	div, mod := new(Uint).DivMod(x, y, new(Uint))
	if !mod.IsZero() {
		div.Add(div, &Uint{1, 0, 0, 0})
	}
	return div
}
