package int256

import "gno.land/p/gnoswap/uint256"

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

func (z *Int) AddOverflow(x, y *Int) (*Int, bool) {
	z = z.initiateAbs()

	if x.neg == y.neg {
		// 같은 부호일 때
		var overflow bool
		z.abs, overflow = z.abs.AddOverflow(x.abs, y.abs)
		z.neg = x.neg

		if overflow {
			return z, true
		}

		// int256의 범위 체크
		if z.neg {
			// 음수일 때: 결과가 MinInt256보다 작은지 확인
			if z.abs.Cmp(MinInt256().abs) > 0 {
				return z, true
			}
		} else {
			// 양수일 때: 결과가 MaxInt256보다 큰지 확인
			if z.abs.Cmp(MaxInt256().abs) > 0 {
				return z, true
			}
		}
	} else {
		// 다른 부호일 때는 절대값의 뺄셈으로 처리
		if x.abs.Cmp(y.abs) >= 0 {
			z.abs.Sub(x.abs, y.abs)
			z.neg = x.neg
		} else {
			z.abs.Sub(y.abs, x.abs)
			z.neg = y.neg
		}
	}

	// 결과가 0인 경우 항상 양수로 처리
	if z.abs.IsZero() {
		z.neg = false
	}

	return z, false
}

// AddUint256 set z to the sum x + y, where y is a uint256, and returns z
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

// Sets z to the sum x + y, where z and x are uint256s and y is an int256.
func AddDelta(z, x *uint256.Uint, y *Int) {
	if y.neg {
		z.Sub(x, y.abs)
	} else {
		z.Add(x, y.abs)
	}
}

// Sets z to the sum x + y, where z and x are uint256s and y is an int256.
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

// SubUint256 set z to the difference x - y, where y is a uint256, and returns z
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

// Mul sets z to the product x*y and returns z.
func (z *Int) Mul(x, y *Int) *Int {
	z = z.initiateAbs()

	z.abs = z.abs.Mul(x.abs, y.abs)
	z.neg = x.neg != y.neg && !z.abs.IsZero() // 0 has no sign
	return z
}

// MulUint256 sets z to the product x*y, where y is a uint256, and returns z
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

// Div sets z to the quotient x/y for y != 0 and returns z.
func (z *Int) Div(x, y *Int) *Int {
	z = z.initiateAbs()

	if y.abs.IsZero() {
		panic("division by zero")
	}

	z.abs.Div(x.abs, y.abs)
	z.neg = (x.neg != y.neg) && !z.abs.IsZero() // 0 has no sign

	return z
}

// DivUint256 sets z to the quotient x/y, where y is a uint256, and returns z
// If y == 0, z is set to 0
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
// If y == 0, a division-by-zero run-time panic occurs.
// OBS: differs from mempooler int256, we need to panic manually if y == 0
// Quo implements truncated division (like Go); see QuoRem for more details.
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
// If y == 0, a division-by-zero run-time panic occurs.
// OBS: differs from mempooler int256, we need to panic manually if y == 0
// Rem implements truncated modulus (like Go); see QuoRem for more details.
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
// If y == 0, z is set to 0 (OBS: differs from the big.Int)
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

// 2^255 - 1
func MaxInt256() *Int {
	return MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819967")
}

// -2^255
func MinInt256() *Int {
	return MustFromDecimal("-57896044618658097711785492504343953926634992332820282019728792003956564819968")
}
