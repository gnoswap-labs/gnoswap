package pool

import "gno.land/p/demo/ufmt"

func liquidityMathAddDelta(x bigint, y bigint) bigint {
	if y < 0 {
		z := x - (-y)
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() #1 || expected z(%d) >= 0", z))
		require(z < x, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || expected z(%d) < x(%d)", z, x))
		return z
	} else {
		z := x + y
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() #2 || expected z(%d) >= 0", z))
		require(z >= x, ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || expected z(%d) >= x(%d)", z, x))
		return z
	}
}
