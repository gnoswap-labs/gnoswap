package pool

import (
	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/u256"
)

func liquidityMathAddDelta(x *u256.Uint, y *u256.Int) *u256.Uint {
	if y.IsNeg() {
		z := new(u256.Uint).Sub(x, y.Abs())
		require(z.Lt(x), ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%d) < x(%d)", z, x))
		return z
	} else {
		z := new(u256.Uint).Add(x, y.Uint())
		require(z.Gte(x), ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%d) >= x(%d)", z, x))
		return z
	}
}
