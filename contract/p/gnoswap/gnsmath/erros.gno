package gnsmath

import (
	"errors"
)

var (
	errInvalidPoolSqrtPrice     = errors.New("invalid pool sqrt price calculation: product/amount != sqrtPX96 or numerator1 <= product")
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
)
