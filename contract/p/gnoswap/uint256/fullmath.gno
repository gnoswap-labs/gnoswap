// REF: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
package uint256

import (
	"gno.land/p/demo/ufmt"
)

const (
	MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
)

func MulDiv(
	a, b, denominator *Uint,
) *Uint {
	hi, lo := mul256(a, b)

	if hi.IsZero() {
		if !(denominator.Gt(Zero())) { // require(denominator > 0);
			panic(ufmt.Sprintf("denominator must be greater than 0. got %s", denominator.ToString()))
		}
		// overflow cannot happen here
		return new(Uint).Div(lo, denominator)
	}

	if !(denominator.Gt(hi)) { // require(denominator > prod1)
		panic(ufmt.Sprintf("denominator(%s) must be greater than hi(%s)", denominator.ToString(), hi.ToString()))
	}

	remainder := new(Uint).MulMod(a, b, denominator)

	// Subtract remainder from [hi, lo] to make it divisible
	// borrow(=1) if remainder > lo
	if remainder.Gt(lo) {
		hi = new(Uint).Sub(hi, One())
	}
	lo = new(Uint).Sub(lo, remainder)

	// factor out how many powers of 2 the denominator has
	twos := new(Uint).And(new(Uint).Neg(denominator), denominator)
	denominator = new(Uint).Div(denominator, twos)
	lo = new(Uint).Div(lo, twos)

	// denominator is now odd, so find its inverse mod 2^256 using Newton-Raphson
	inv := Zero()
	inv = new(Uint).Mul(NewUint(3), denominator)
	inv = new(Uint).Xor(inv, NewUint(2))

	// Newton-Raphson iteration
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**8
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**16
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**32
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**64
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**128
	inv = new(Uint).Mul(inv, new(Uint).Sub(NewUint(2), new(Uint).Mul(denominator, inv))) // inverse mod 2**256

	// multiply [hi, lo] with inv in mod 2^256 -> final quotient
	// flip twos to 2^256/twos and multiply + shift hi and or with lo
	twos = new(Uint).Add(
		new(Uint).Div(
			new(Uint).Sub(Zero(), twos),
			twos,
		),
		One(),
	)
	lo = new(Uint).Or(lo, new(Uint).Mul(hi, twos))

	result := new(Uint).Mul(lo, inv)
	return result
}

func MulDivRoundingUp(
	a, b, denominator *Uint,
) *Uint {
	result := MulDiv(a, b, denominator)

	if new(Uint).MulMod(a, b, denominator).Gt(Zero()) {
		if !(result.Lt(MustFromDecimal(MAX_UINT256))) { // require(result < MAX_UINT256)
			panic(ufmt.Sprintf("uint256_MulDivRoundingUp()__result(%s) < MAX_UINT256", result.ToString()))
		}

		result = new(Uint).Add(result, One())
	}

	return result
}

// UnsafeMath
// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/libraries/UnsafeMath.sol
func DivRoundingUp(
	x, y *Uint,
) *Uint {
	div := new(Uint).Div(x, y)
	mod := new(Uint).Mod(x, y)

	z := new(Uint).Add(div, gt(mod, Zero()))
	return z
}

func gt(x, y *Uint) *Uint {
	if x.Gt(y) {
		return One()
	}
	return Zero()
}

// mul256 returns the 512-bit product of a * b in two 256-bit parts: (hi, lo).
// a, b, hi, lo are all assumed to be little-endian [4]uint64.
func mul256(a, b *Uint) (hi, lo *Uint) {
	var p [8]uint64

	for i := 0; i < 4; i++ {
		carry := uint64(0)
		ai := a.arr[i]
		for j := 0; j < 4; j++ {
			// Perform 64-bit × 64-bit = 128-bit multiplication
			hi64, lo64 := bits_mul64(ai, b.arr[j])

			// Add p[i+j] and carry
			sum1, c1 := bits_add64(lo64, p[i+j], 0)
			sum2, c2 := bits_add64(sum1, carry, 0)

			p[i+j] = sum2

			// Move upper 64 bits and carries to next position
			carry = hi64 + c1 + c2
		}
		p[i+4] += carry
	}

	lo = &Uint{arr: [4]uint64{p[0], p[1], p[2], p[3]}}
	hi = &Uint{arr: [4]uint64{p[4], p[5], p[6], p[7]}}
	return hi, lo
}

// multiply two 64-bit numbers and return 128-bit result
func bits_mul64(x, y uint64) (hi, lo uint64) {
	const mask32 = 1<<32 - 1

	x0 := x & mask32
	x1 := x >> 32
	y0 := y & mask32
	y1 := y >> 32

	w0 := x0 * y0
	t := x1*y0 + (w0 >> 32)
	w1 := t & mask32
	w2 := t >> 32
	w1 += x0 * y1
	hi = x1*y1 + w2 + (w1 >> 32)
	lo = x * y
	return
}

// 64-bit addition with carry
func bits_add64(x, y, carry uint64) (sum, carryOut uint64) {
	sum = x + y + carry
	// Carry out occurs when:
	// 1) Overflow in x + y
	// 2) Overflow in (x + y) + carry
	carryOut = ((x & y) | ((x | y) & ^sum)) >> 63
	return
}
