package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/ufmt"
)

// liquidityMathAddDelta calculates the new liquidity by applying the delta liquidity to the current liquidity.
// If delta liquidity is negative, it subtracts the absolute value of delta liquidity from the current liquidity.
// If delta liquidity is positive, it adds the absolute value of delta liquidity to the current liquidity.
// Returns the new liquidity as a uint256 value.
func liquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if x == nil || y == nil {
		panic(newErrorWithDetail(
			errInvalidInput,
			"x or y is nil",
		))
	}

	absDelta := y.Abs()

	// Subtract or add based on the sign of y
	if y.IsNeg() {
		z := u256.Zero().Sub(x, absDelta)
		if z.Gte(x) {
			panic(newErrorWithDetail(
				errLiquidityCalculation,
				ufmt.Sprintf("Condition failed: (z must be < x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
			))
		}
		return z
	}
	z := u256.Zero().Add(x, absDelta)
	if z.Lt(x) {
		panic(newErrorWithDetail(
			errLiquidityCalculation,
			ufmt.Sprintf("Condition failed: (z must be >= x) (x: %s, y: %s, z:%s)", x.ToString(), y.ToString(), z.ToString()),
		))
	}
	return z
}
