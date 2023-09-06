package gnoswap

import "gno.land/p/demo/ufmt"

func liquidityMathAddDelta(x bigint, y bigint) bigint {
	if y < 0 {
		z := x - (-y)
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%s) >= 0__#1", z))
		require(z < x, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%s) < x(%s)", z, x))
		return z
	} else {
		z := x + y
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%s) >= 0__#2", z))
		require(z >= x, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || z(%s) >= x(%s)", z, x))
		return z
	}
}
