package gnsmath

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidPoolSqrtPrice     = "invalid pool sqrt price calculation: product/amount != sqrtPX96 or numerator1 <= product"
	errSqrtPriceOverflow        = "sqrt price overflow"
	errSqrtPriceExceedsQuotient = "sqrt price exceeds calculated quotient"
	errSqrtPriceZero            = "sqrtPX96 should not be zero"
	errLiquidityZero            = "liquidity should not be zero"
	errSqrtRatioAX96Zero        = "sqrtRatioAX96 must be greater than zero"
	errAmount0DeltaOverflow     = "GetAmount0Delta: overflow"
	errAmount1DeltaOverflow     = "GetAmount1Delta: overflow"
	errMSBZeroInput             = "input for MSB calculation should not be zero"
	errLSBZeroInput             = "input for LSB calculation should not be zero"
	errGetAmount0DeltaNilInput  = "GetAmount0Delta: input parameters cannot be nil"
	errGetAmount1DeltaNilInput  = "GetAmount1Delta: input parameters cannot be nil"
	errTickMathOutOfRange       = "tick_math: value out of range"
	errTickMathInvalidInput     = "tick_math: invalid input data"
	errTickMathOverflow         = "tick_math: overflow"
	errLiquidityIdenticalTicks  = "liquidity_math: identical ticks"
	errLiquidityOverflow        = "liquidity_math: overflow"
	errSafeMathOverflow         = "safe_math: overflow"
)

func newErrorWithDetail(errMsg string, detail string) string {
	return ufmt.Errorf("%s || %s", errMsg, detail).Error()
}
