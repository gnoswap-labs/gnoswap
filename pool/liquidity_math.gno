package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/ufmt"
)

// liquidityMathAddDelta Calculate the new liquidity with delta liquidity.
// If delta liquidity is negative, it will subtract the absolute value of delta liquidity from the current liquidity.
// If delta liquidity is positive, it will add the absolute value of delta liquidity to the current liquidity.
// inputs:
// - x: current liquidity
// - y: delta liquidity
// Returns the new liquidity.
func liquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if x == nil || y == nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("liquidity_math.gno__liquidityMathAddDelta() || x or y is nil"),
		))
	}

	absDelta := y.Abs()
	var z *u256.Uint

	// Subtract or add based on the sign of y
	if y.Lt(i256.Zero()) {
		z = new(u256.Uint).Sub(x, absDelta)
		if z.Gte(x) { // z must be < x
			panic(addDetailToError(
				errLiquidityCalculation,
				ufmt.Sprintf("liquidity_math.gno__liquidityMathAddDelta() || LS(z must be < x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	} else {
		z = new(u256.Uint).Add(x, absDelta)
		if z.Lt(x) { // z must be >= x
			panic(addDetailToError(
				errLiquidityCalculation,
				ufmt.Sprintf("liquidity_math.gno__liquidityMathAddDelta() || LA(z must be >= x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
	}

	return z
}
