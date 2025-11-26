package common

import (
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// readAllocatorBytesForLiquidity parses runtime.MemStats() into the current allocated bytes.
func readAllocatorBytesForLiquidity(t *testing.T) int64 {
	t.Helper()
	stats := runtime.MemStats()
	if stats == "nil allocator" {
		return 0
	}
	if !strings.HasPrefix(stats, "Allocator{") || !strings.HasSuffix(stats, "}") {
		t.Fatalf("unexpected runtime.MemStats output: %q", stats)
	}
	body := strings.TrimSuffix(strings.TrimPrefix(stats, "Allocator{"), "}")
	parts := strings.Split(body, ", ")
	if len(parts) != 2 {
		t.Fatalf("unexpected runtime.MemStats content: %q", stats)
	}
	var (
		bytes int64
		found bool
	)
	for _, part := range parts {
		fields := strings.Split(part, ":")
		if len(fields) != 2 {
			t.Fatalf("unexpected runtime.MemStats pair %q", part)
		}
		if fields[0] == "bytes" {
			val, err := strconv.ParseInt(fields[1], 10, 64)
			if err != nil {
				t.Fatalf("failed to parse bytes from %q: %v", part, err)
			}
			bytes = val
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("bytes key not found in runtime.MemStats output: %q", stats)
	}
	return bytes
}

type LiquidityMetricResult struct {
	Name       string
	Iterations int
	DurationNs int64
	AllocDelta int64
}

// runLiquidityMetric executes fn the given number of iterations while logging elapsed time and allocation deltas.
func runLiquidityMetric(t *testing.T, name string, iterations int, fn func()) LiquidityMetricResult {
	t.Helper()

	// Skip GC if allocator is nil to avoid panic
	stats := runtime.MemStats()
	if stats != "nil allocator" {
		runtime.GC()
	}
	beforeBytes := readAllocatorBytesForLiquidity(t)
	start := time.Now()
	for i := 0; i < iterations; i++ {
		fn()
	}
	elapsed := time.Since(start)
	afterBytes := readAllocatorBytesForLiquidity(t)

	return LiquidityMetricResult{
		Name:       name,
		Iterations: iterations,
		DurationNs: elapsed.Nanoseconds(),
		AllocDelta: afterBytes - beforeBytes,
	}
}

func TestLiquidityAmountsRuntimeMetrics(t *testing.T) {
	const iterations = 200
	var results []LiquidityMetricResult

	// Test input values - common price ratios in Q64.96 format
	sqrtRatioX96Current := u256.MustFromDecimal("79228162514264337593543950336")   // sqrt(1) = 1.0
	sqrtRatioX96Low := u256.MustFromDecimal("56022770974786139918731938227")       // sqrt(0.5) ≈ 0.707
	sqrtRatioX96High := u256.MustFromDecimal("112045541949572279837463876454")     // sqrt(2) ≈ 1.414
	sqrtRatioX96VeryLow := u256.MustFromDecimal("7922816251426433759")             // sqrt(0.00001)
	sqrtRatioX96VeryHigh := u256.MustFromDecimal("792281625142643375935439503360") // sqrt(100000)

	// Edge case ratios
	sqrtRatioX96Min := u256.MustFromDecimal("4295128739")                                        // Min sqrt ratio
	sqrtRatioX96Max := u256.MustFromDecimal("1461446703485210103287273052203988822378723970341") // Max sqrt ratio

	// Liquidity amounts
	liquidityMedium := u256.MustFromDecimal("1000000000000")                            // 1T
	liquidityLarge := u256.MustFromDecimal("1000000000000000000")                       // 1Q
	liquidityMax := u256.MustFromDecimal(MAX_UINT128)                                   // Max uint128
	liquidityHalfMax := u256.MustFromDecimal("170141183460469231731687303715884105727") // Half of max uint128

	// Token amounts
	amount0Small := u256.MustFromDecimal("100000")
	amount0Medium := u256.MustFromDecimal("100000000000")
	amount0Large := u256.MustFromDecimal("100000000000000000")
	amount1Small := u256.MustFromDecimal("50000")
	amount1Medium := u256.MustFromDecimal("50000000000")
	amount1Large := u256.MustFromDecimal("50000000000000000")

	// Delta values for LiquidityMathAddDelta
	deltaPositiveSmall := i256.MustFromDecimal("1000000")
	deltaPositiveLarge := i256.MustFromDecimal("1000000000000000")
	deltaNegativeSmall := i256.MustFromDecimal("-1000000")
	deltaNegativeLarge := i256.MustFromDecimal("-1000000000000000")

	tests := []struct {
		name string
		run  func(t *testing.T) LiquidityMetricResult
	}{
		// toAscendingOrder tests
		{
			name: "toAscendingOrder_AlreadyOrdered",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "toAscendingOrder_AlreadyOrdered", iterations, func() {
					_, _ = toAscendingOrder(sqrtRatioX96Low, sqrtRatioX96High)
				})
			},
		},
		{
			name: "toAscendingOrder_NeedsSwap",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "toAscendingOrder_NeedsSwap", iterations, func() {
					_, _ = toAscendingOrder(sqrtRatioX96High, sqrtRatioX96Low)
				})
			},
		},
		// toUint128 tests
		{
			name: "toUint128_WithinRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "toUint128_WithinRange", iterations, func() {
					_ = toUint128(liquidityMedium)
				})
			},
		},
		{
			name: "toUint128_MaxValue",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "toUint128_MaxValue", iterations, func() {
					_ = toUint128(liquidityMax)
				})
			},
		},
		// safeConvertToUint128 tests
		{
			name: "safeConvertToUint128_Valid",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "safeConvertToUint128_Valid", iterations, func() {
					_ = safeConvertToUint128(liquidityHalfMax)
				})
			},
		},
		// computeLiquidityForAmount0 tests
		{
			name: "computeLiquidityForAmount0_Normal",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount0_Normal", iterations, func() {
					_ = computeLiquidityForAmount0(sqrtRatioX96Low, sqrtRatioX96High, amount0Medium)
				})
			},
		},
		{
			name: "computeLiquidityForAmount0_SmallRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount0_SmallRange", iterations, func() {
					sqrtLow := u256.MustFromDecimal("79228162514264337593543950336")
					sqrtHigh := u256.MustFromDecimal("79300000000000000000000000000")
					_ = computeLiquidityForAmount0(sqrtLow, sqrtHigh, amount0Small)
				})
			},
		},
		{
			name: "computeLiquidityForAmount0_LargeRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount0_LargeRange", iterations, func() {
					_ = computeLiquidityForAmount0(sqrtRatioX96VeryLow, sqrtRatioX96VeryHigh, amount0Large)
				})
			},
		},
		// computeLiquidityForAmount1 tests
		{
			name: "computeLiquidityForAmount1_Normal",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount1_Normal", iterations, func() {
					_ = computeLiquidityForAmount1(sqrtRatioX96Low, sqrtRatioX96High, amount1Medium)
				})
			},
		},
		{
			name: "computeLiquidityForAmount1_SmallRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount1_SmallRange", iterations, func() {
					sqrtLow := u256.MustFromDecimal("79228162514264337593543950336")
					sqrtHigh := u256.MustFromDecimal("79300000000000000000000000000")
					_ = computeLiquidityForAmount1(sqrtLow, sqrtHigh, amount1Small)
				})
			},
		},
		{
			name: "computeLiquidityForAmount1_LargeRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeLiquidityForAmount1_LargeRange", iterations, func() {
					_ = computeLiquidityForAmount1(sqrtRatioX96VeryLow, sqrtRatioX96VeryHigh, amount1Large)
				})
			},
		},
		// GetLiquidityForAmounts tests
		{
			name: "GetLiquidityForAmounts_CurrentBelowRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetLiquidityForAmounts_CurrentBelowRange", iterations, func() {
					_ = GetLiquidityForAmounts(sqrtRatioX96Low, sqrtRatioX96Current, sqrtRatioX96High, amount0Medium, amount1Medium)
				})
			},
		},
		{
			name: "GetLiquidityForAmounts_CurrentInRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetLiquidityForAmounts_CurrentInRange", iterations, func() {
					_ = GetLiquidityForAmounts(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, amount0Medium, amount1Medium)
				})
			},
		},
		{
			name: "GetLiquidityForAmounts_CurrentAboveRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetLiquidityForAmounts_CurrentAboveRange", iterations, func() {
					_ = GetLiquidityForAmounts(sqrtRatioX96High, sqrtRatioX96Low, sqrtRatioX96Current, amount0Medium, amount1Medium)
				})
			},
		},
		{
			name: "GetLiquidityForAmounts_EdgeCase_MinMax",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetLiquidityForAmounts_EdgeCase_MinMax", iterations, func() {
					_ = GetLiquidityForAmounts(sqrtRatioX96Current, sqrtRatioX96Min, sqrtRatioX96Max, amount0Small, amount1Small)
				})
			},
		},
		// computeAmount0ForLiquidity tests
		{
			name: "computeAmount0ForLiquidity_Normal",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount0ForLiquidity_Normal", iterations, func() {
					_ = computeAmount0ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, liquidityMedium)
				})
			},
		},
		{
			name: "computeAmount0ForLiquidity_LargeLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount0ForLiquidity_LargeLiquidity", iterations, func() {
					_ = computeAmount0ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, liquidityLarge)
				})
			},
		},
		{
			name: "computeAmount0ForLiquidity_ZeroLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount0ForLiquidity_ZeroLiquidity", iterations, func() {
					_ = computeAmount0ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, u256.Zero())
				})
			},
		},
		// computeAmount1ForLiquidity tests
		{
			name: "computeAmount1ForLiquidity_Normal",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount1ForLiquidity_Normal", iterations, func() {
					_ = computeAmount1ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, liquidityMedium)
				})
			},
		},
		{
			name: "computeAmount1ForLiquidity_LargeLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount1ForLiquidity_LargeLiquidity", iterations, func() {
					_ = computeAmount1ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, liquidityLarge)
				})
			},
		},
		{
			name: "computeAmount1ForLiquidity_ZeroLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "computeAmount1ForLiquidity_ZeroLiquidity", iterations, func() {
					_ = computeAmount1ForLiquidity(sqrtRatioX96Low, sqrtRatioX96High, u256.Zero())
				})
			},
		},
		// GetAmountsForLiquidity tests
		{
			name: "GetAmountsForLiquidity_CurrentBelowRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetAmountsForLiquidity_CurrentBelowRange", iterations, func() {
					_, _ = GetAmountsForLiquidity(sqrtRatioX96Low, sqrtRatioX96Current, sqrtRatioX96High, liquidityMedium)
				})
			},
		},
		{
			name: "GetAmountsForLiquidity_CurrentInRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetAmountsForLiquidity_CurrentInRange", iterations, func() {
					_, _ = GetAmountsForLiquidity(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, liquidityMedium)
				})
			},
		},
		{
			name: "GetAmountsForLiquidity_CurrentAboveRange",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetAmountsForLiquidity_CurrentAboveRange", iterations, func() {
					_, _ = GetAmountsForLiquidity(sqrtRatioX96High, sqrtRatioX96Low, sqrtRatioX96Current, liquidityMedium)
				})
			},
		},
		{
			name: "GetAmountsForLiquidity_ZeroLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetAmountsForLiquidity_ZeroLiquidity", iterations, func() {
					_, _ = GetAmountsForLiquidity(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, u256.Zero())
				})
			},
		},
		{
			name: "GetAmountsForLiquidity_MaxLiquidity",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "GetAmountsForLiquidity_MaxLiquidity", iterations, func() {
					_, _ = GetAmountsForLiquidity(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, liquidityMax)
				})
			},
		},
		// LiquidityMathAddDelta tests
		{
			name: "LiquidityMathAddDelta_AddSmall",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "LiquidityMathAddDelta_AddSmall", iterations, func() {
					_ = LiquidityMathAddDelta(liquidityMedium, deltaPositiveSmall)
				})
			},
		},
		{
			name: "LiquidityMathAddDelta_AddLarge",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "LiquidityMathAddDelta_AddLarge", iterations, func() {
					_ = LiquidityMathAddDelta(liquidityMedium, deltaPositiveLarge)
				})
			},
		},
		{
			name: "LiquidityMathAddDelta_SubtractSmall",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "LiquidityMathAddDelta_SubtractSmall", iterations, func() {
					_ = LiquidityMathAddDelta(liquidityMedium, deltaNegativeSmall)
				})
			},
		},
		{
			name: "LiquidityMathAddDelta_SubtractLarge",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "LiquidityMathAddDelta_SubtractLarge", iterations, func() {
					_ = LiquidityMathAddDelta(liquidityLarge, deltaNegativeLarge)
				})
			},
		},
		// Combined/Complex operations
		{
			name: "Combined_LiquidityRoundtrip",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "Combined_LiquidityRoundtrip", iterations, func() {
					// Get liquidity from amounts, then get amounts back
					liq := GetLiquidityForAmounts(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, amount0Medium, amount1Medium)
					_, _ = GetAmountsForLiquidity(sqrtRatioX96Current, sqrtRatioX96Low, sqrtRatioX96High, liq)
				})
			},
		},
		{
			name: "Combined_MultipleAddDelta",
			run: func(t *testing.T) LiquidityMetricResult {
				return runLiquidityMetric(t, "Combined_MultipleAddDelta", iterations, func() {
					liq := liquidityMedium
					liq = LiquidityMathAddDelta(liq, deltaPositiveSmall)
					liq = LiquidityMathAddDelta(liq, deltaNegativeSmall)
					_ = LiquidityMathAddDelta(liq, deltaPositiveLarge)
				})
			},
		},
	}

	for i := range tests {
		test := tests[i]
		t.Run(test.name, func(t *testing.T) {
			result := test.run(t)
			results = append(results, result)
		})
	}

	// Print results as markdown table
	t.Log("\n## Liquidity Amounts Runtime Metrics Results\n")
	t.Log("| Function | Iterations | Duration (ns) | Alloc Delta (bytes) |")
	t.Log("|----------|------------|---------------|---------------------|")
	for _, result := range results {
		t.Logf("| %s | %d | %d | %d |", result.Name, result.Iterations, result.DurationNs, result.AllocDelta)
	}
}
