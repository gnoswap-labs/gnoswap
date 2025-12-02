// Gas and performance metrics for r/gnoswap/common package
// Test cases are identical to tests/integration/testdata/base/common_gas_measurement.txtar
package main

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/scenario/metric"
)

var t *testing.T

func main() {
	TickMathGetSqrtRatioAtTick_MinTick()
	TickMathGetSqrtRatioAtTick_MaxTick()
	TickMathGetSqrtRatioAtTick_Zero()
	TickMathGetSqrtRatioAtTick()
	TickMathGetTickAtSqrtRatio()
	GetLiquidityForAmounts()
	GetAmountsForLiquidity()
	LiquidityMathAddDelta_Positive()
	LiquidityMathAddDelta_Negative()
	LiquidityMathAddDelta()
	IsGNOTPath()
	IsGNOTNativePath()
	IsGNOTWrappedPath()
	ExistsUserSendCoins()
}

// Common Package Functions - Identical to common_gas_measurement.txtar

func TickMathGetSqrtRatioAtTick_MinTick() {
	metric.PrintMetricsBy("TickMathGetSqrtRatioAtTick (minTick)", func() {
		common.TickMathGetSqrtRatioAtTick(-887272)
	})
}

func TickMathGetSqrtRatioAtTick_MaxTick() {
	metric.PrintMetricsBy("TickMathGetSqrtRatioAtTick (maxTick)", func() {
		common.TickMathGetSqrtRatioAtTick(887272)
	})
}

func TickMathGetSqrtRatioAtTick_Zero() {
	metric.PrintMetricsBy("TickMathGetSqrtRatioAtTick (zero)", func() {
		common.TickMathGetSqrtRatioAtTick(0)
	})
}

func TickMathGetSqrtRatioAtTick() {
	metric.PrintMetricsBy("TickMathGetSqrtRatioAtTick", func() {
		common.TickMathGetSqrtRatioAtTick(1000)
	})
}

func TickMathGetTickAtSqrtRatio() {
	metric.PrintMetricsBy("TickMathGetTickAtSqrtRatio", func() {
		sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
		common.TickMathGetTickAtSqrtRatio(sqrtPriceX96)
	})
}

func GetLiquidityForAmounts() {
	metric.PrintMetricsBy("GetLiquidityForAmounts", func() {
		sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
		sqrtPriceAX96 := u256.MustFromDecimal("70710678118654752440084436210")
		sqrtPriceBX96 := u256.MustFromDecimal("88817841970012523233890533447")
		amount0 := u256.MustFromDecimal("1000000")
		amount1 := u256.MustFromDecimal("1000000")

		common.GetLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1)
	})
}

func GetAmountsForLiquidity() {
	metric.PrintMetricsBy("GetAmountsForLiquidity", func() {
		sqrtPriceX96 := u256.MustFromDecimal("79228162514264337593543950336")
		sqrtPriceAX96 := u256.MustFromDecimal("70710678118654752440084436210")
		sqrtPriceBX96 := u256.MustFromDecimal("88817841970012523233890533447")
		liquidity := u256.MustFromDecimal("1000000")

		common.GetAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, liquidity)
	})
}

func LiquidityMathAddDelta_Positive() {
	metric.PrintMetricsBy("LiquidityMathAddDelta (positive)", func() {
		x := u256.MustFromDecimal("1000000")
		y := i256.MustFromDecimal("500000")

		common.LiquidityMathAddDelta(x, y)
	})
}

func LiquidityMathAddDelta_Negative() {
	metric.PrintMetricsBy("LiquidityMathAddDelta (negative)", func() {
		x := u256.MustFromDecimal("1000000")
		y := i256.MustFromDecimal("-300000")

		common.LiquidityMathAddDelta(x, y)
	})
}

func LiquidityMathAddDelta() {
	metric.PrintMetricsBy("LiquidityMathAddDelta", func() {
		x := u256.MustFromDecimal("1000000")
		y := i256.MustFromDecimal("500000")

		common.LiquidityMathAddDelta(x, y)
	})
}

func IsGNOTPath() {
	metric.PrintMetricsBy("IsGNOTPath", func() {
		common.IsGNOTPath("ugnot")
	})
}

func IsGNOTNativePath() {
	metric.PrintMetricsBy("IsGNOTNativePath", func() {
		common.IsGNOTNativePath("ugnot")
	})
}

func IsGNOTWrappedPath() {
	metric.PrintMetricsBy("IsGNOTWrappedPath", func() {
		common.IsGNOTWrappedPath("gno.land/r/gnoland/wugnot")
	})
}

func ExistsUserSendCoins() {
	metric.PrintMetricsBy("ExistsUserSendCoins", func() {
		common.ExistsUserSendCoins()
	})
}
