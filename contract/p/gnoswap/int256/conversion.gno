package int256

import (
	"gno.land/p/gnoswap/uint256"
)

// SetInt64 sets z to x and returns z.
//
// This implementation uses two's complement to handle the edge case of math.MinInt64.
// When x = math.MinInt64 (-2^63), negating it would cause an overflow since 2^63
// cannot be represented as a positive int64. By converting to uint64 first and then
// applying two's complement (^u + 1) when negative, we correctly handle all int64
// values including the minimum value without overflow.
func (z *Int) SetInt64(x int64) *Int {
	z = z.initiateAbs()
	if z.abs == nil {
		panic("int256_SetInt64(): abs is nil")
	}
	u := uint64(x)
	neg := x < 0
	if neg {
		u = ^u + 1 // |x| = two's complement magnitude
	}
	z.abs = z.abs.SetUint64(u)
	z.neg = neg && u != 0 // prevent -0
	return z
}

// SetUint64 sets z to x and returns z.
func (z *Int) SetUint64(x uint64) *Int {
	z = z.initiateAbs()

	if z.abs == nil {
		panic("int256_SetUint64(): abs is nil")
	}
	z.abs = z.abs.SetUint64(x)
	z.neg = false
	return z
}

// Uint64 returns the lower 64 bits of z as a uint64.
func (z *Int) Uint64() uint64 {
	return z.abs.Uint64()
}

// Int64 returns the lower 64 bits of z, interpreted as a signed int64 (two's complement).
//
// Since int64 already uses two's complement representation internally,
// we can simply apply two's complement to the unsigned magnitude when negative and cast
// to int64. This approach correctly handles all edge cases including when the magnitude
// equals 2^63 (which represents math.MinInt64 when negative) without special casing.
func (z *Int) Int64() int64 {
	u := z.abs.Uint64() // lower 64 bits of magnitude
	if z.neg {
		u = ^u + 1 // apply two's complement for negative sign
	}
	return int64(u) // reinterpret as two's complement int64
}

// Neg sets z to -x and returns z.
func (z *Int) Neg(x *Int) *Int {
	z.abs.Set(x.abs)
	if z.abs.IsZero() {
		z.neg = false
	} else {
		z.neg = !x.neg
	}
	return z
}

// NegOverflow sets z to -x and returns z and whether overflow occurred.
// Overflow occurs when negating the minimum int256 value (-2^255).
func (z *Int) NegOverflow(x *Int) (*Int, bool) {
	z = z.initiateAbs()

	if x.IsZero() {
		z.abs.Clear()
		z.neg = false
		return z, false
	}

	if x.neg && x.abs.Eq(MinInt256().abs) {
		z.Set(x) // must preserve the original value
		return z, true
	}

	z.abs.Set(x.abs)
	z.neg = !x.neg

	return z, false
}

// Set sets z to x and returns z.
func (z *Int) Set(x *Int) *Int {
	z.abs.Set(x.abs)
	z.neg = x.neg
	return z
}

// SetUint256 sets z to the value of x and returns z.
func (z *Int) SetUint256(x *uint256.Uint) *Int {
	z.abs.Set(x)
	z.neg = false
	return z
}

// ToString returns the decimal string representation of z.
// Panics if z is nil.
// This differs from the original mempooler int256 implementation.
func (z *Int) ToString() string {
	if z == nil {
		panic("int256: nil pointer to ToString()")
	}

	t := z.abs.Dec()
	if z.neg {
		return "-" + t
	}
	return t
}
