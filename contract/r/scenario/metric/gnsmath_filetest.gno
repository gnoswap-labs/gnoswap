// Gas and performance metrics for p/gnoswap/gnsmath package
// Test cases are identical to tests/integration/testdata/base/gnsmath_gas_measurement.txtar
package main

import (
	"testing"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/gnsmath"
)

var t *testing.T

func main() {
	ufmt.Println("=== GnsMath Package Metrics ===")
	println()

	ufmt.Println("[TEST] GetAmount0Delta")
	TestGetAmount0Delta()
	println()

	ufmt.Println("[TEST] GetAmount1Delta")
	TestGetAmount1Delta()
	println()

	ufmt.Println("[TEST] SwapMathComputeSwapStep")
	TestSwapMathComputeSwapStep()
	println()

	ufmt.Println("=== All Metrics Completed ===")
}

// GnsMath Package Functions - Identical to gnsmath_gas_measurement.txtar

func TestGetAmount0Delta() {
	sqrtRatioAX96 := u256.MustFromDecimal("79228162514264337593543950336")
	sqrtRatioBX96 := u256.MustFromDecimal("87150978765690771352898345369")
	liquidity := i256.MustFromDecimal("1000000000000000000")

	result := gnsmath.GetAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TestGetAmount1Delta() {
	sqrtRatioAX96 := u256.MustFromDecimal("79228162514264337593543950336")
	sqrtRatioBX96 := u256.MustFromDecimal("87150978765690771352898345369")
	liquidity := i256.MustFromDecimal("1000000000000000000")

	result := gnsmath.GetAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TestSwapMathComputeSwapStep() {
	currentX96 := u256.MustFromDecimal("79228162514264337593543950336")
	targetX96 := u256.MustFromDecimal("80120444139456980969479389824")
	liquidity := u256.MustFromDecimal("2000000000000000000")
	amountRemaining := i256.MustFromDecimal("1000000000000000000")
	feePips := uint64(600)

	sqrtRatioNextX96, amountIn, amountOut, feeAmount := gnsmath.SwapMathComputeSwapStep(
		currentX96,
		targetX96,
		liquidity,
		amountRemaining,
		feePips,
	)
	ufmt.Printf("sqrtRatioNextX96: %s\n", sqrtRatioNextX96.ToString())
	ufmt.Printf("amountIn: %s\n", amountIn.ToString())
	ufmt.Printf("amountOut: %s\n", amountOut.ToString())
	ufmt.Printf("feeAmount: %s\n", feeAmount.ToString())
}

// Output:
// === GnsMath Package Metrics ===
//
// [TEST] GetAmount0Delta
// Result: 90909090909090910
//
// [TEST] GetAmount1Delta
// Result: 100000000000000000
//
// [TEST] SwapMathComputeSwapStep
// sqrtRatioNextX96: 80120444139456980969479389824
// amountIn: 22524354897969416
// amountOut: 22273506712956942
// feeAmount: 13522726574727
//
// === All Metrics Completed ===
