package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func LiquidityMathAddDelta(lastStakedLiquidity *u256.Uint, delta *i256.Int) *u256.Uint {
	return gnsmath.LiquidityMathAddDelta(lastStakedLiquidity, delta)
}
