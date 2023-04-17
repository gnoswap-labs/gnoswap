package gnoswap

import (
	"math"
)

// x should be unsigned
func LiquidityMathAddDelta(x bigint, y bigint) bigint {
	if y < 0 {
		z := x - (-y)
		require(z >= 0, "FIX MINUS // LiquidityMathAddDelta")
		require(z < x, "LS")
		return z
	} else {
		z := x + y
		require(z >= 0, "FIX MINUS // LiquidityMathAddDelta")
		require(z >= x, "LA")
		return z
	}
}