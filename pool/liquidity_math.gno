package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func liquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if y.Lt(i256.Zero()) {
		z := new(u256.Uint).Sub(x, y.Abs())

		if !(z.Lt(x)) {
			panic("LS")
		}
		return z // z < x
	} else {
		z := new(u256.Uint).Add(x, y.Abs())

		if !(z.Gte(x)) {
			panic("LA")
		}
		return z // z >= x
	}
}
