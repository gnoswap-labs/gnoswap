// Gas and performance metrics for r/gnoswap/common package
// Test cases are identical to tests/integration/testdata/base/common_gas_measurement.txtar
package main

import (
	"testing"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"
)

var t *testing.T

func main() {
	ufmt.Println("=== Common Package Metrics ===")
	println()

	ufmt.Println("[TEST] TickMathGetSqrtRatioAtTick (minTick)")
	TickMathGetSqrtRatioAtTick_MinTick()
	println()

	ufmt.Println("[TEST] TickMathGetSqrtRatioAtTick (maxTick)")
	TickMathGetSqrtRatioAtTick_MaxTick()
	println()

	ufmt.Println("[TEST] TickMathGetSqrtRatioAtTick (zero)")
	TickMathGetSqrtRatioAtTick_Zero()
	println()

	ufmt.Println("[TEST] TickMathGetSqrtRatioAtTick")
	TickMathGetSqrtRatioAtTick()
	println()

	ufmt.Println("[TEST] TickMathGetTickAtSqrtRatio")
	TickMathGetTickAtSqrtRatio()
	println()

	ufmt.Println("[TEST] GetLiquidityForAmounts")
	GetLiquidityForAmounts()
	println()

	ufmt.Println("[TEST] GetAmountsForLiquidity")
	GetAmountsForLiquidity()
	println()

	ufmt.Println("[TEST] LiquidityMathAddDelta (positive)")
	LiquidityMathAddDelta_Positive()
	println()

	ufmt.Println("[TEST] LiquidityMathAddDelta (negative)")
	LiquidityMathAddDelta_Negative()
	println()

	ufmt.Println("[TEST] LiquidityMathAddDelta")
	LiquidityMathAddDelta()
	println()

	ufmt.Println("[TEST] IsGNOTPath")
	IsGNOTPath()
	println()

	ufmt.Println("[TEST] IsGNOTNativePath")
	IsGNOTNativePath()
	println()

	ufmt.Println("[TEST] IsGNOTWrappedPath")
	IsGNOTWrappedPath()
	println()

	ufmt.Println("[TEST] ExistsUserSendCoins")
	ExistsUserSendCoins()
	println()

	ufmt.Println("=== All Metrics Completed ===")
}

// Common Package Functions - Identical to common_gas_measurement.txtar

func TickMathGetSqrtRatioAtTick_MinTick() {
	result := common.TickMathGetSqrtRatioAtTick(-887272)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TickMathGetSqrtRatioAtTick_MaxTick() {
	result := common.TickMathGetSqrtRatioAtTick(887272)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TickMathGetSqrtRatioAtTick_Zero() {
	result := common.TickMathGetSqrtRatioAtTick(0)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TickMathGetSqrtRatioAtTick() {
	result := common.TickMathGetSqrtRatioAtTick(1000)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func TickMathGetTickAtSqrtRatio() {
	sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
	result := common.TickMathGetTickAtSqrtRatio(sqrtPriceX96)
	ufmt.Printf("Result: %d\n", result)
}

func GetLiquidityForAmounts() {
	sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
	sqrtPriceAX96 := u256.MustFromDecimal("70710678118654752440084436210")
	sqrtPriceBX96 := u256.MustFromDecimal("88817841970012523233890533447")
	amount0 := u256.MustFromDecimal("1000000")
	amount1 := u256.MustFromDecimal("1000000")

	result := common.GetLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func GetAmountsForLiquidity() {
	sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
	sqrtPriceAX96 := u256.MustFromDecimal("70710678118654752440084436210")
	sqrtPriceBX96 := u256.MustFromDecimal("88817841970012523233890533447")
	liquidity := u256.MustFromDecimal("1000000")

	amount0, amount1 := common.GetAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, liquidity)
	ufmt.Printf("Amount0: %s, Amount1: %s\n", amount0, amount1)
}

func LiquidityMathAddDelta_Positive() {
	x := u256.MustFromDecimal("1000000")
	y := i256.MustFromDecimal("500000")

	result := common.LiquidityMathAddDelta(x, y)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func LiquidityMathAddDelta_Negative() {
	x := u256.MustFromDecimal("1000000")
	y := i256.MustFromDecimal("-300000")

	result := common.LiquidityMathAddDelta(x, y)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func LiquidityMathAddDelta() {
	x := u256.MustFromDecimal("1000000")
	y := i256.MustFromDecimal("500000")

	result := common.LiquidityMathAddDelta(x, y)
	ufmt.Printf("Result: %s\n", result.ToString())
}

func IsGNOTPath() {
	result := common.IsGNOTPath("ugnot")
	ufmt.Printf("Result: %t\n", result)
}

func IsGNOTNativePath() {
	result := common.IsGNOTNativePath("ugnot")
	ufmt.Printf("Result: %t\n", result)
}

func IsGNOTWrappedPath() {
	result := common.IsGNOTWrappedPath("gno.land/r/gnoland/wugnot")
	ufmt.Printf("Result: %t\n", result)
}

func ExistsUserSendCoins() {
	result := common.ExistsUserSendCoins()
	ufmt.Printf("Result: %t\n", result)
}

// Output:
// === Common Package Metrics ===
//
// [TEST] TickMathGetSqrtRatioAtTick (minTick)
// Result: 4295128739
//
// [TEST] TickMathGetSqrtRatioAtTick (maxTick)
// Result: 1461446703485210103287273052203988822378723970342
//
// [TEST] TickMathGetSqrtRatioAtTick (zero)
// Result: 79228162514264337593543950336
//
// [TEST] TickMathGetSqrtRatioAtTick
// Result: 83290069058676223003182343270
//
// [TEST] TickMathGetTickAtSqrtRatio
// Result: 0
//
// [TEST] GetLiquidityForAmounts
// Result: 9261815
//
// [TEST] GetAmountsForLiquidity
// Amount0: 107970, Amount1: 107505
//
// [TEST] LiquidityMathAddDelta (positive)
// Result: 1500000
//
// [TEST] LiquidityMathAddDelta (negative)
// Result: 700000
//
// [TEST] LiquidityMathAddDelta
// Result: 1500000
//
// [TEST] IsGNOTPath
// Result: true
//
// [TEST] IsGNOTNativePath
// Result: true
//
// [TEST] IsGNOTWrappedPath
// Result: true
//
// [TEST] ExistsUserSendCoins
// Result: false
//
// === All Metrics Completed ===
