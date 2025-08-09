package int256

import "gno.land/p/gnoswap/uint256"

// Add sets z to the sum x+y and returns z.
func (z *Int) Add(x, y *Int) *Int {
	z = z.initiateAbs()

	if x.neg == y.neg {
		// If both numbers have the same sign, add their absolute values
		z.abs.Add(x.abs, y.abs)
		z.neg = x.neg
	} else {
		// If signs are different, subtract the smaller absolute value from the larger
		if x.abs.Cmp(y.abs) >= 0 {
			z.abs.Sub(x.abs, y.abs)
			z.neg = x.neg
		} else {
			z.abs.Sub(y.abs, x.abs)
			z.neg = y.neg
		}
	}

	// Ensure zero is always positive
	if z.abs.IsZero() {
		z.neg = false
	}

	return z
}

// AddOverflow sets z to the sum x+y and returns z and whether overflow occurred.
// Overflow occurs when the result exceeds the int256 range [-2^255, 2^255-1].
func (z *Int) AddOverflow(x, y *Int) (*Int, bool) {
	z = z.initiateAbs()

	if x.neg == y.neg {
		// same sign
		var overflow bool
		z.abs, overflow = z.abs.AddOverflow(x.abs, y.abs)
		z.neg = x.neg

		if overflow {
			return z, true
		}

		// check int256 range
		if z.neg {
			if z.abs.Cmp(MinInt256().abs) > 0 {
				return z, true
			}
		} else {
			if z.abs.Cmp(MaxInt256().abs) > 0 {
				return z, true
			}
		}
	} else {
		// handle different sign by subtracting absolute values
		if x.abs.Cmp(y.abs) >= 0 {
			z.abs.Sub(x.abs, y.abs)
			z.neg = x.neg
		} else {
			z.abs.Sub(y.abs, x.abs)
			z.neg = y.neg
		}
	}

	// overflow can be happen when result is 0
	if z.abs.IsZero() {
		z.neg = false
	}

	return z, false
}

// AddUint256 sets z to the sum x+y, where y is a uint256, and returns z.
func (z *Int) AddUint256(x *Int, y *uint256.Uint) *Int {
	z = z.initiateAbs()

	if x.neg {
		if x.abs.Gt(y) {
			z.abs.Sub(x.abs, y)
			z.neg = true
		} else {
			z.abs.Sub(y, x.abs)
			z.neg = false
		}
	} else {
		z.abs.Add(x.abs, y)
		z.neg = false
	}
	return z
}

// AddDelta adds a signed int256 value y to an unsigned uint256 value x and stores the result in z.
func AddDelta(z, x *uint256.Uint, y *Int) {
	if y.neg {
		z.Sub(x, y.abs)
	} else {
		z.Add(x, y.abs)
	}
}

// AddDeltaOverflow adds a signed int256 value y to an unsigned uint256 value x, stores the result in z,
// and returns true if overflow occurs.
func AddDeltaOverflow(z, x *uint256.Uint, y *Int) bool {
	var overflow bool
	if y.neg {
		_, overflow = z.SubOverflow(x, y.abs)
	} else {
		_, overflow = z.AddOverflow(x, y.abs)
	}
	return overflow
}

// Sub sets z to the difference x-y and returns z.
func (z *Int) Sub(x, y *Int) *Int {
	z = z.initiateAbs()

	if x.neg != y.neg {
		// If sign are different, add the absolute values
		z.abs.Add(x.abs, y.abs)
		z.neg = x.neg
	} else {
		// If signs are the same, subtract the smaller absolute value from the larger
		if x.abs.Cmp(y.abs) >= 0 {
			z.abs = z.abs.Sub(x.abs, y.abs)
			z.neg = x.neg
		} else {
			z.abs.Sub(y.abs, x.abs)
			z.neg = !x.neg
		}
	}

	// Ensure zero is always positive
	if z.abs.IsZero() {
		z.neg = false
	}
	return z
}

// SubUint256 sets z to the difference x-y, where y is a uint256, and returns z.
func (z *Int) SubUint256(x *Int, y *uint256.Uint) *Int {
	z = z.initiateAbs()

	if x.neg {
		z.abs.Add(x.abs, y)
		z.neg = true
	} else {
		if x.abs.Lt(y) {
			z.abs.Sub(y, x.abs)
			z.neg = true
		} else {
			z.abs.Sub(x.abs, y)
			z.neg = false
		}
	}
	return z
}

// SubOverflow sets z to the difference x-y and returns z and whether overflow occurred.
// Overflow occurs when subtracting a positive number from the minimum int256 value
// or a negative number from the maximum int256 value.
func (z *Int) SubOverflow(x, y *Int) (*Int, bool) {
	z = z.initiateAbs()

	// must keep the original value of y
	negY := y.Clone()
	negY.neg = !y.neg && !y.IsZero() // reverse sign if y is not zero

	// x + (-y)
	return z.AddOverflow(x, negY)
}

// Mul sets z to the product x*y and returns z.
func (z *Int) Mul(x, y *Int) *Int {
	z = z.initiateAbs()

	z.abs = z.abs.Mul(x.abs, y.abs)
	z.neg = x.neg != y.neg && !z.abs.IsZero() // 0 has no sign
	return z
}

// MulUint256 sets z to the product x*y, where y is a uint256, and returns z.
func (z *Int) MulUint256(x *Int, y *uint256.Uint) *Int {
	z = z.initiateAbs()

	z.abs.Mul(x.abs, y)
	if z.abs.IsZero() {
		z.neg = false
	} else {
		z.neg = x.neg
	}
	return z
}

// MulOverflow sets z to the product x*y and returns z and whether overflow occurred.
// Multiplication frequently overflows when multiplying large numbers or when
// the product exceeds the int256 range [-2^255, 2^255-1].
func (z *Int) MulOverflow(x, y *Int) (*Int, bool) {
	z = z.initiateAbs()

	// always 0. no need to check overflow
	if x.IsZero() || y.IsZero() {
		z.abs.Clear()
		z.neg = false
		return z, false
	}

	// multiply with absolute values
	absResult, overflow := z.abs.MulOverflow(x.abs, y.abs)
	z.abs = absResult

	// calculate the result's sign
	z.neg = x.neg != y.neg

	if overflow {
		return z, true
	}

	if z.neg {
		if z.abs.Cmp(MinInt256().abs) > 0 {
			return z, true
		}
	} else {
		if z.abs.Cmp(MaxInt256().abs) > 0 {
			return z, true
		}
	}

	return z, false
}

// Div sets z to the quotient x/y for y != 0 and returns z.
// Panics if y == 0.
func (z *Int) Div(x, y *Int) *Int {
	z = z.initiateAbs()

	if y.abs.IsZero() {
		panic("division by zero")
	}

	z.abs.Div(x.abs, y.abs)
	z.neg = (x.neg != y.neg) && !z.abs.IsZero() // 0 has no sign

	return z
}

// DivUint256 sets z to the quotient x/y, where y is a uint256, and returns z.
// If y == 0, z is set to 0.
func (z *Int) DivUint256(x *Int, y *uint256.Uint) *Int {
	z = z.initiateAbs()

	z.abs.Div(x.abs, y)
	if z.abs.IsZero() {
		z.neg = false
	} else {
		z.neg = x.neg
	}
	return z
}

// Quo sets z to the quotient x/y for y != 0 and returns z.
// It implements truncated division (like Go). Panics if y == 0.
// This differs from mempooler int256 which requires manual panic handling.
func (z *Int) Quo(x, y *Int) *Int {
	if y.IsZero() {
		panic("division by zero")
	}

	z = z.initiateAbs()

	z.abs = z.abs.Div(x.abs, y.abs)
	z.neg = !(z.abs.IsZero()) && x.neg != y.neg // 0 has no sign
	return z
}

// Rem sets z to the remainder x%y for y != 0 and returns z.
// It implements truncated modulus (like Go). Panics if y == 0.
// This differs from mempooler int256 which requires manual panic handling.
func (z *Int) Rem(x, y *Int) *Int {
	if y.IsZero() {
		panic("division by zero")
	}

	z = z.initiateAbs()

	z.abs.Mod(x.abs, y.abs)
	z.neg = z.abs.Sign() > 0 && x.neg // 0 has no sign
	return z
}

// Mod sets z to the modulus x%y for y != 0 and returns z.
// If y == 0, z is set to 0 (differs from big.Int behavior).
func (z *Int) Mod(x, y *Int) *Int {
	z = z.initiateAbs()

	if x.neg {
		z.abs.Div(x.abs, y.abs)
		z.abs.Add(z.abs, one)
		z.abs.Mul(z.abs, y.abs)
		z.abs.Sub(z.abs, x.abs)
		z.abs.Mod(z.abs, y.abs)
	} else {
		z.abs.Mod(x.abs, y.abs)
	}
	z.neg = false
	return z
}

// MaxInt256 returns the maximum value for a 256-bit signed integer (2^255 - 1).
func MaxInt256() *Int {
	return MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819967")
}

// MinInt256 returns the minimum value for a 256-bit signed integer (-2^255).
func MinInt256() *Int {
	return MustFromDecimal("-57896044618658097711785492504343953926634992332820282019728792003956564819968")
}
