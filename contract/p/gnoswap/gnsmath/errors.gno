package gnsmath

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var (
	errInvalidPoolSqrtPrice     = errors.New("invalid pool sqrt price calculation: product/amount != sqrtPX96 or numerator1 <= product")
	errSqrtPriceOverflow        = errors.New("sqrt price overflow")
	errSqrtPriceExceedsQuotient = errors.New("sqrt price exceeds calculated quotient")
	errSqrtPriceZero            = errors.New("sqrtPX96 should not be zero")
	errLiquidityZero            = errors.New("liquidity should not be zero")
	errSqrtRatioAX96Zero        = errors.New("sqrtRatioAX96 must be greater than zero")
	errAmount0DeltaOverflow     = errors.New("GetAmount0Delta: overflow")
	errAmount1DeltaOverflow     = errors.New("GetAmount1Delta: overflow")
	errMSBZeroInput             = errors.New("input for MSB calculation should not be zero")
	errLSBZeroInput             = errors.New("input for LSB calculation should not be zero")
	errGetAmount0DeltaNilInput  = errors.New("GetAmount0Delta: input parameters cannot be nil")
	errGetAmount1DeltaNilInput  = errors.New("GetAmount1Delta: input parameters cannot be nil")
	errTickMathOutOfRange       = errors.New("tick_math: value out of range")
	errTickMathInvalidInput     = errors.New("tick_math: invalid input data")
	errTickMathOverflow         = errors.New("tick_math: overflow")
	errLiquidityIdenticalTicks  = errors.New("liquidity_math: identical ticks")
	errLiquidityOverflow        = errors.New("liquidity_math: overflow")
)

func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}
