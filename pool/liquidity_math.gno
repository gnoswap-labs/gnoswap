package gnoswap



func LiquidityMathAddDelta(x bigint, y bigint) bigint {
	if y < 0 {
		z := x - (-y)
		requireUnsigned(z, "liquidity_math.gno__LiquidityMathAddDelta__z #1")
		require(z < x, "[X] LS")
		return z
	} else {
		z := x + y
		requireUnsigned(z, "liquidity_math.gno__LiquidityMathAddDelta__z #2")
		require(z >= x, "[X] LA")
		return z
	}
}