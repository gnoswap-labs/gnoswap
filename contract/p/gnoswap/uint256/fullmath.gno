// REF: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
package uint256

import (
	"gno.land/p/demo/ufmt"
)

const (
	MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
)

// MulDiv multiplies two numbers and divides the result by a third number.
// It performs multiplication and division while handling overflow checking.
// The calculation is performed with full precision and rounding down.
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
//   - If the intermediate product's high 256 bits are greater than or equal to denominator
func MulDiv(
	a, b, denominator *Uint,
) *Uint {
	p := umul(a, b) // 512-bit product of a * b

	lo := &Uint{arr: [4]uint64{p[0], p[1], p[2], p[3]}}
	hi := &Uint{arr: [4]uint64{p[4], p[5], p[6], p[7]}}

	if hi.IsZero() {
		if denominator.IsZero() {
			panic(ufmt.Sprintf("denominator must be greater than 0. got %s", denominator.ToString()))
		}
		// overflow cannot happen here
		return new(Uint).Div(lo, denominator)
	}

	if denominator.Lte(hi) {
		panic(ufmt.Sprintf("denominator(%s) must be greater than hi(%s)", denominator.ToString(), hi.ToString()))
	}

	remainder := new(Uint).MulMod(a, b, denominator)

	// Subtract remainder from [hi, lo] to make it divisible
	// borrow(=1) if remainder > lo
	if remainder.Gt(lo) {
		hi = new(Uint).Sub(hi, one)
	}
	lo = new(Uint).Sub(lo, remainder)

	// factor out how many powers of 2 the denominator has
	twos := new(Uint).And(new(Uint).Neg(denominator), denominator)
	denominator = new(Uint).Div(denominator, twos)
	lo = new(Uint).Div(lo, twos)

	// denominator is now odd, so find its inverse mod 2^256 using Newton-Raphson
	inv := zero
	inv = new(Uint).Mul(three, denominator)
	inv = new(Uint).Xor(inv, two)

	// Newton-Raphson iteration
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**8
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**16
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**32
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**64
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**128
	inv = new(Uint).Mul(inv, new(Uint).Sub(two, new(Uint).Mul(denominator, inv))) // inverse mod 2**256

	// multiply [hi, lo] with inv in mod 2^256 -> final quotient
	// flip twos to 2^256/twos and multiply + shift hi and or with lo
	twos = new(Uint).Add(
		new(Uint).Div(
			new(Uint).Sub(zero, twos),
			twos,
		),
		one,
	)
	lo = new(Uint).Or(lo, new(Uint).Mul(hi, twos))

	result := new(Uint).Mul(lo, inv)
	return result
}

// MulDivRoundingUp multiplies two numbers and divides the result by a third number,
// rounding up the result if there is any remainder.
//
// Parameters:
//   - a: First multiplicand
//   - b: Second multiplicand
//   - denominator: The divisor (must be greater than 0)
//
// Returns:
//   - The result of (a * b) / denominator, rounded up if there is any remainder
//
// Panics:
//   - If the result would overflow uint256
//   - If denominator is 0
//   - If the intermediate product's high 256 bits are greater than or equal to denominator
func MulDivRoundingUp(
	a, b, denominator *Uint,
) *Uint {
	result := MulDiv(a, b, denominator)

	if new(Uint).MulMod(a, b, denominator).Lte(zero) {
		return result
	}

	if result.Gte(MustFromDecimal(MAX_UINT256)) {
		panic(ufmt.Sprintf("result(%s) < MAX_UINT256", result.ToString()))
	}

	return new(Uint).Add(result, one)
}

// DivRoundingUp performs division of two numbers, rounding up the result
// if there is any remainder.
//
// Parameters:
//   - x: Dividend
//   - y: Divisor (must be greater than 0)
//
// Returns:
//   - The result of x / y, rounded up if there is any remainder
//
// Note:
//   - This is an unsafe math operation and does not perform overflow checks
//
// Reference:
//   - https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/libraries/UnsafeMath.sol
func DivRoundingUp(
	x, y *Uint,
) *Uint {
	div := new(Uint).Div(x, y)
	mod := new(Uint).Mod(x, y)

	z := new(Uint).Add(div, gt(mod, zero))
	return z
}

// gt returns one if x is greater than y, zero otherwise.
// This is a helper function for DivRoundingUp.
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
	return zero
}
