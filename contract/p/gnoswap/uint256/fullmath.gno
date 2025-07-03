// REF: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol

// Package fullmath implements Uniswap V3's FullMath library.
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
	"gno.land/p/demo/ufmt"
)

// MulDiv calculates (a * b) / denominator with full 512-bit intermediate precision.
// This implementation uses stack-allocated variables with clear naming conventions
// to ensure safety while reducing heap allocations.
//
// Parameters:
//   - a: First multiplicand
//   - b: Second multiplicand
//   - denominator: The divisor (must be greater than 0)
//
// Returns:
//   - The result of (a * b) / denominator, rounded down
//
// Panics:
//   - If denominator is 0
//   - If the result would overflow 256 bits
func MulDiv(a, b, denominator *Uint) *Uint {
	// Pre-allocate variables with explicit names indicating their purpose
	var loProduct, hiProduct Uint // Low and high parts of the 512-bit product
	var remainder Uint            // For the remainder calculation
	var twos Uint                 // For factoring out powers of 2
	var denomCopy Uint            // For working copy of denominator
	var tempCalc Uint             // For intermediate calculations
	var inverse Uint              // For multiplicative inverse
	var result Uint               // For final result

	// Compute the 512-bit product of a * b
	p := umul(a, b)

	// Split the 512-bit product into high and low 256-bit parts
	loProduct.arr = [4]uint64{p[0], p[1], p[2], p[3]}
	hiProduct.arr = [4]uint64{p[4], p[5], p[6], p[7]}

	// If the high part is zero, we can use simple 256-bit division
	if hiProduct.IsZero() {
		if denominator.IsZero() {
			panic(ufmt.Sprintf("denominator must be greater than 0. got %s", denominator.ToString()))
		}
		// Use direct division when high part is zero
		result.Div(&loProduct, denominator)
		return &result
	}

	// Ensure the result will fit in 256 bits
	if denominator.Lte(&hiProduct) {
		panic(ufmt.Sprintf("overflow: denominator(%s) must be greater than hi(%s)",
			denominator.ToString(), hiProduct.ToString()))
	}

	// Compute the remainder of (a * b) mod denominator
	remainder.MulMod(a, b, denominator)

	// Subtract remainder from [hi, lo] to make it divisible by denominator
	// If remainder > lo, we need to borrow from hi
	if remainder.Gt(&loProduct) {
		// Need to borrow from hi, so decrement hi by 1
		tempCalc.Sub(&hiProduct, one)
		hiProduct = tempCalc // Safe assignment since original hiProduct is no longer needed
	}

	tempCalc.Sub(&loProduct, &remainder)
	loProduct = tempCalc // Safe assignment since original loProduct is no longer needed

	// Factor out powers of 2 from denominator
	// This optimization leverages the fact that division by powers of 2 is just bit shifting
	tempCalc.Neg(denominator)
	twos.And(&tempCalc, denominator)

	// Create a safe copy of denominator for division
	denomCopy.Div(denominator, &twos)

	// Divide lo by twos
	tempCalc.Div(&loProduct, &twos)
	loProduct = tempCalc // Safe reassignment

	// Find the multiplicative inverse of the odd denominator modulo 2^256
	// Start with a good initial guess: inverse = 3 * denominator XOR 2
	tempCalc.Mul(three, &denomCopy)
	inverse.Xor(&tempCalc, two)

	// Newton-Raphson iteration: inv = inv * (2 - denominator * inv)
	// Using safe temporary calculations for each step
	for i := 0; i < 6; i++ { // 6 iterations for full 256-bit precision
		// Calculate denominator * inv
		tempCalc.Mul(&denomCopy, &inverse)

		// Calculate 2 - denominator * inv
		var subResult Uint
		subResult.Sub(two, &tempCalc)

		// Calculate inv * (2 - denominator * inv)
		tempCalc.Mul(&inverse, &subResult)
		inverse = tempCalc // Safe reassignment
	}

	// Compute the quotient
	// Calculate 2^256 / twos
	var negTwos Uint
	negTwos.Sub(Zero(), &twos)

	var divResult Uint
	divResult.Div(&negTwos, &twos)

	tempCalc.Add(&divResult, one)
	twos = tempCalc // twos now holds 2^256/twos

	// Calculate hi * twos
	tempCalc.Mul(&hiProduct, &twos)

	// Calculate lo | (hi * twos)
	var combined Uint
	combined.Or(&loProduct, &tempCalc)

	// Final multiplication for the result
	result.Mul(&combined, &inverse)
	return &result
}

// MulDivRoundingUp calculates ceil((a * b) / denominator).
// This is useful for ensuring that rounding errors favor the protocol
// rather than users, which is important for security.
//
// Parameters:
//   - a: First multiplicand
//   - b: Second multiplicand
//   - denominator: The divisor (must be greater than 0)
//
// Returns:
//   - The result of (a * b) / denominator, rounded up
//
// Panics:
//   - If denominator is 0
//   - If the result would overflow 256 bits
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

// DivRoundingUp performs division with rounding up.
// This is a simpler operation that doesn't require the full precision of MulDiv.
//
// Parameters:
//   - x: Dividend
//   - y: Divisor (must be greater than 0)
//
// Returns:
//   - The result of x / y, rounded up
//
// Panics:
//   - If y is 0
func DivRoundingUp(x, y *Uint) *Uint {
	if y.IsZero() {
		panic("division by zero")
	}
	div := new(Uint).Div(x, y)
	mod := new(Uint).Mod(x, y)
	z := new(Uint).Add(div, gt(mod, Zero()))
	return z
}

// gt returns one if x is greater than y, zero otherwise.
// This is a branchless helper for conditional increment.
//
// Parameters:
//   - x: First number to compare
//   - y: Second number to compare
//
// Returns:
//   - one if x > y, zero otherwise
func gt(x, y *Uint) *Uint {
	if x.Gt(y) {
		return one
	}
	return Zero()
}
