// REF: https://github.com/Uniswap/solidity-lib/blob/master/contracts/libraries/FullMath.sol
package uint512

import (
	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
)

func fullMul(
	x *u256.Uint,
	y *u256.Uint,
) (*u256.Uint, *u256.Uint) { // l, h
	mm := new(u256.Uint).MulMod(x, y, u256.UnsafeFromDecimal(MAX_UINT256))

	l := new(u256.Uint).Mul(x, y)
	h := new(u256.Uint).Sub(mm, l)

	if mm.Lt(l) {
		h = new(u256.Uint).Sub(h, u256.One())
	}

	return l, h
}

func fullDiv(
	l *u256.Uint,
	h *u256.Uint,
	d *u256.Uint,
) *u256.Uint {
	// uint256 pow2 = d & -d;
	posD := i256.FromUint256(d)
	negD := i256.Zero().Neg(posD)

	intPow2 := i256.Zero().And(posD, negD)
	d = new(u256.Uint).Div(d, intPow2.Abs())
	l = new(u256.Uint).Div(l, intPow2.Abs())

	_negPow2 := new(u256.Uint).Neg(intPow2.Abs())

	value1 := new(u256.Uint).Div(_negPow2, intPow2.Abs())  // (-pow2) / pow2
	value2 := new(u256.Uint).UnsafeAdd(value1, u256.One()) // (-pow2) / pow2 + 1)
	value3 := new(u256.Uint).Mul(h, value2)                // h * ((-pow2) / pow2 + 1);
	l = new(u256.Uint).UnsafeAdd(l, value3)

	r := u256.One()
	for i := 0; i < 8; i++ {
		value1 := new(u256.Uint).Mul(d, r)                    // d * r
		value2 := new(u256.Uint).Sub(u256.NewUint(2), value1) // 2 - ( d * r )
		r = new(u256.Uint).Mul(r, value2)                     // r *= 2 - d * r;
	}
	res := new(u256.Uint).Mul(l, r)
	return res
}

func MulDiv(
	x *u256.Uint,
	y *u256.Uint,
	d *u256.Uint,
) *u256.Uint {
	l, h := fullMul(x, y)
	mm := new(u256.Uint).MulMod(x, y, d)

	if mm.Gt(l) {
		h = new(u256.Uint).Sub(h, u256.One())
	}
	l = new(u256.Uint).Sub(l, mm)

	if h.IsZero() {
		return new(u256.Uint).Div(l, d)
	}

	if !(h.Lt(d)) {
		panic("FULLDIV_OVERFLOW")
	}

	return fullDiv(l, h, d)
}

func MulDivRoundingUp(
	x *u256.Uint,
	y *u256.Uint,
	d *u256.Uint,
) *u256.Uint {
	result := MulDiv(x, y, d)

	// _mm := new(u256.Uint).MulMod(x, y, d)
	// if _mm.Gt(u256.Zero()) {
	// 	if result.Lt(u256.UnsafeFromDecimal(MAX_UINT256)) {
	// 		result = new(u256.Uint).Add(result, u256.One())
	// 	}
	// }

	return result
}

func DivRoundingUp(
	x *u256.Uint,
	y *u256.Uint,
) *u256.Uint {
	div := new(u256.Uint).Div(x, y)

	mod := new(u256.Uint).Mod(x, y)
	return new(u256.Uint).Add(div, gt(mod, u256.Zero()))
}

// HELPERs
func lt(x, y *u256.Uint) *u256.Uint {
	if x.Lt(y) {
		return u256.One()
	} else {
		return u256.Zero()
	}
}

func gt(x, y *u256.Uint) *u256.Uint {
	if x.Gt(y) {
		return u256.One()
	} else {
		return u256.Zero()
	}
}
