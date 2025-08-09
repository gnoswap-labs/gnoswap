package int256

import (
	"gno.land/p/gnoswap/uint256"
)

// Abs returns the absolute value of z.
func (z *Int) Abs() *uint256.Uint {
	return z.abs.Clone()
}

// AbsGt returns true if the absolute value of z is greater than x.
func (z *Int) AbsGt(x *uint256.Uint) bool {
	return z.abs.Gt(x)
}

// AbsLt returns true if the absolute value of z is less than x.
func (z *Int) AbsLt(x *uint256.Uint) bool {
	return z.abs.Lt(x)
}

// AbsOverflow sets z to the absolute value of x and returns z and whether overflow occurred.
// Overflow occurs when x is the minimum int256 value (-2^255), as its absolute value (2^255)
// cannot be represented in a signed 256-bit integer.
func (z *Int) AbsOverflow(x *Int) (*Int, bool) {
	z = z.initiateAbs()

	// overflow can be happen when negating a minimum of int256 value
	if x.neg && x.abs.Eq(MinInt256().abs) {
		z.Set(x) // keep the original value
		return z, true
	}

	z.abs.Set(x.abs)
	z.neg = false

	return z, false
}
