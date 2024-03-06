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
	mm := new(u256.Uint).MulMod(x, y, u256.UnsafeFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935"))

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

	// l += h * ((-pow2) / pow2 + 1);
	_negPow2 := new(u256.Uint).Sub(u256.UnsafeFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935"), intPow2.Abs())
	_negPow2 = new(u256.Uint).Add(_negPow2, u256.One())

	value1 := new(u256.Uint).Div(_negPow2, intPow2.Abs()) // (-pow2) / pow2
	// println("value1:", value1.ToString())

	value2 := new(u256.Uint).UnsafeAdd(value1, u256.One()) // (-pow2) / pow2 + 1)
	// println("value2:", value2.ToString())

	// _intH := i256.FromUint256(h)
	value3 := new(u256.Uint).Mul(h, value2) // h * ((-pow2) / pow2 + 1);
	l = new(u256.Uint).UnsafeAdd(l, value3)

	r := u256.One()

	// r *= 2 - d * r; [ x8 ]
	// value11 := new(u256.Uint).UnsafeSub(u256.NewUint(2), d) // 2 - d
	// value12 := new(u256.Uint).Mul(value11, r)               // 2 - d * r
	// r = new(u256.Uint).Mul(r, value12)                      // r *= 2 - d * r;

	//  d * r
	// 2 - ( d * r )

	for i := 0; i < 8; i++ {
		value1 := new(u256.Uint).Mul(d, r)                          // d * r
		value2 := new(u256.Uint).UnsafeSub(u256.NewUint(2), value1) // 2 - ( d * r )
		r = new(u256.Uint).Mul(r, value2)                           // r *= 2 - d * r;

	}

	println("l:", l.ToString())
	println("r:", r.ToString())

	res := new(u256.Uint).Mul(l, r)
	println("res:", res.ToString())
	return res
	// return new(u256.Uint).Mul(l, r)

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

func DivRoundingUp(
	x *u256.Uint,
	y *u256.Uint,
) *u256.Uint {
	div := new(u256.Uint).Div(x, y)

	mod := new(u256.Uint).Mod(x, y)
	gt := u256.Zero()
	if mod.Gt(u256.Zero()) {
		gt = mod
	} else {
		gt = u256.Zero()
	}

	return new(u256.Uint).Add(div, gt)
}

// HELPERs
func mulmod(
	x *u256.Uint,
	y *u256.Uint,
	z *u256.Uint,
) *u256.Uint {
	mul := new(u256.Uint).Mul(x, y)
	mod := new(u256.Uint).Mod(mul, z)

	return mod
}
