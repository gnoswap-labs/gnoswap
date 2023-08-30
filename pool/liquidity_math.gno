package gnoswap

import "gno.land/p/demo/ufmt"

func LiquidityMathAddDelta(x bigint, y bigint) bigint {
	if y < 0 {
		z := x - (-y)
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__LiquidityMathAddDelta() || z must be positive #1 (%s)", z))
		require(z < x, ufmt.Sprintf("[POOL] liquidity_math.gno__LiquidityMathAddDelta() || z(%s) < x(%s)", z, x))
		return z
	} else {
		z := x + y
		requireUnsigned(z, ufmt.Sprintf("[POOL] liquidity_math.gno__LiquidityMathAddDelta() || z must be positive #2 (%s)", z))
		require(z >= x, ufmt.Sprintf("[POOL] liquidity_math.gno__LiquidityMathAddDelta() || z(%s) >= x(%s)", z, x))
		return z
	}
}
