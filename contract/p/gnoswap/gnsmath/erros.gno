package gnsmath

import (
	"errors"
)

var (
	errSqrtPriceExceedsQuotient   = errors.New("sqrt price exceeds calculated quotient")
	errSqrtPriceZero              = errors.New("sqrtPX96 should not be zero")
	errLiquidityZero              = errors.New("liquidity should not be zero")
	errSqrtRatioAX96Zero          = errors.New("sqrtRatioAX96 must be greater than zero")
	errMultiplicationOverflow     = errors.New("multiplication overflow in price calculation")
	errInsufficientLiquidity      = errors.New("insufficient liquidity for token0 removal")
	errAmount0DeltaOverflow       = errors.New("GetAmount0DeltaStr: overflow")
	errAmount1DeltaOverflow       = errors.New("GetAmount1DeltaStr: overflow")
	errMSBZeroInput               = errors.New("input for MSB calculation should not be zero")
	errLSBZeroInput               = errors.New("input for LSB calculation should not be zero")
	errGetAmount0DeltaStrNilInput = errors.New("GetAmount0DeltaStr: input parameters cannot be nil")
	errGetAmount1DeltaStrNilInput = errors.New("GetAmount1DeltaStr: input parameters cannot be nil")
)
