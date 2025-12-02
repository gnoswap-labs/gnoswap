// Gas and performance metrics for p/gnoswap/gnsmath package
// Test cases are identical to tests/integration/testdata/base/gnsmath_gas_measurement.txtar
package main

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenario/metric"
)

var t *testing.T

func main() {
	TestGetAmount0Delta()
	TestGetAmount1Delta()
	TestSwapMathComputeSwapStep()
}

// GnsMath Package Functions - Identical to gnsmath_gas_measurement.txtar

func TestGetAmount0Delta() {
	metric.PrintMetricsBy("GetAmount0Delta", func() {
		sqrtRatioAX96 := u256.MustFromDecimal("79228162514264337593543950336")
		sqrtRatioBX96 := u256.MustFromDecimal("87150978765690771352898345369")
		liquidity := i256.MustFromDecimal("1000000000000000000")

		gnsmath.GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	})
}

func TestGetAmount1Delta() {
	metric.PrintMetricsBy("GetAmount1Delta", func() {
		sqrtRatioAX96 := u256.MustFromDecimal("79228162514264337593543950336")
		sqrtRatioBX96 := u256.MustFromDecimal("87150978765690771352898345369")
		liquidity := i256.MustFromDecimal("1000000000000000000")

		gnsmath.GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	})
}

func TestSwapMathComputeSwapStep() {
	metric.PrintMetricsBy("SwapMathComputeSwapStep", func() {
		currentX96 := u256.MustFromDecimal("79228162514264337593543950336")
		targetX96 := u256.MustFromDecimal("80120444139456980969479389824")
		liquidity := u256.MustFromDecimal("2000000000000000000")
		amountRemaining := i256.MustFromDecimal("1000000000000000000")
		feePips := uint64(600)

		gnsmath.SwapMathComputeSwapStep(
			currentX96,
			targetX96,
			liquidity,
			amountRemaining,
			feePips,
		)
	})
}
