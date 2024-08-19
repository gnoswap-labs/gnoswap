package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/ufmt"
)

func liquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if y.Lt(i256.Zero()) {
		z := new(u256.Uint).Sub(x, y.Abs())

		if !(z.Lt(x)) {
			panic(ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || LS (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()))
		}
		return z // z < x
	}

	z := new(u256.Uint).Add(x, y.Abs())

	if !(z.Gte(x)) {
		panic(ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || LA (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()))
	}
	return z // z >= x
}
