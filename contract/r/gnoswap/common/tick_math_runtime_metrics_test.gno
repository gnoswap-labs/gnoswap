package common

import (
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
)

// readAllocatorBytes parses runtime.MemStats() into the current allocated bytes.
func readAllocatorBytes(t *testing.T) int64 {
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

type MetricResult struct {
	Name       string
	Iterations int
	DurationNs int64
	AllocDelta int64
}

// runMetric executes fn the given number of iterations while logging elapsed time and allocation deltas.
func runMetric(t *testing.T, name string, iterations int, fn func()) MetricResult {
	t.Helper()

	// Skip GC if allocator is nil to avoid panic
	stats := runtime.MemStats()
	if stats != "nil allocator" {
		runtime.GC()
	}
	beforeBytes := readAllocatorBytes(t)
	start := time.Now()
	for i := 0; i < iterations; i++ {
		fn()
	}
	elapsed := time.Since(start)
	afterBytes := readAllocatorBytes(t)

	return MetricResult{
		Name:       name,
		Iterations: iterations,
		DurationNs: elapsed.Nanoseconds(),
		AllocDelta: afterBytes - beforeBytes,
	}
}

func TestTickMathRuntimeMetrics(t *testing.T) {
	const iterations = 200
	var results []MetricResult

	// Test input values covering various ranges
	// Edge cases
	minSqrtPrice := u256.MustFromDecimal("4295128739")                                          // Min sqrt ratio
	maxSqrtPrice := u256.MustFromDecimal("1461446703485210103287273052203988822378723970341")   // Max sqrt ratio - 1
	
	// Common values in typical price ranges
	midSqrtPrice := u256.MustFromDecimal("79228162514264337593543950336")                      // sqrt(1) in X96 format
	lowSqrtPrice := u256.MustFromDecimal("56022770974786139918731938227")                       // sqrt(0.5) in X96 format
	highSqrtPrice := u256.MustFromDecimal("112045541949572279837463876454")                     // sqrt(2) in X96 format
	
	// More extreme but valid prices
	veryLowSqrtPrice := u256.MustFromDecimal("7922816251426433759")                            // sqrt(0.00001) in X96 format
	veryHighSqrtPrice := u256.MustFromDecimal("792281625142643375935439503360000")             // sqrt(100000) in X96 format

	// Test ticks covering various ranges
	minTickVal := int32(-887272)
	maxTickVal := int32(887272)
	zeroTick := int32(0)
	negativeTick := int32(-69082)  // ~0.5 price
	positiveTick := int32(69082)   // ~2 price
	smallNegativeTick := int32(-100)
	smallPositiveTick := int32(100)
	
	tests := []struct {
		name string
		run  func(t *testing.T) MetricResult
	}{
		// TickMathGetSqrtRatioAtTick tests
		{
			name: "GetSqrtRatioAtTick_MinTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_MinTick", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(minTickVal)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_MaxTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_MaxTick", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(maxTickVal)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_ZeroTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_ZeroTick", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(zeroTick)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_NegativeTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_NegativeTick", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(negativeTick)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_PositiveTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_PositiveTick", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(positiveTick)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_SmallNegative",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_SmallNegative", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(smallNegativeTick)
				})
			},
		},
		{
			name: "GetSqrtRatioAtTick_SmallPositive",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetSqrtRatioAtTick_SmallPositive", iterations, func() {
					_ = TickMathGetSqrtRatioAtTick(smallPositiveTick)
				})
			},
		},
		// TickMathGetTickAtSqrtRatio tests
		{
			name: "GetTickAtSqrtRatio_MinSqrtPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_MinSqrtPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(minSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_MaxSqrtPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_MaxSqrtPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(maxSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_MidSqrtPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_MidSqrtPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(midSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_LowSqrtPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_LowSqrtPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(lowSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_HighSqrtPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_HighSqrtPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(highSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_VeryLowPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_VeryLowPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(veryLowSqrtPrice)
				})
			},
		},
		{
			name: "GetTickAtSqrtRatio_VeryHighPrice",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "GetTickAtSqrtRatio_VeryHighPrice", iterations, func() {
					_ = TickMathGetTickAtSqrtRatio(veryHighSqrtPrice)
				})
			},
		},
		// Combined test - roundtrip conversion
		{
			name: "Roundtrip_TickToSqrtToTick",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "Roundtrip_TickToSqrtToTick", iterations, func() {
					sqrtPrice := TickMathGetSqrtRatioAtTick(negativeTick)
					_ = TickMathGetTickAtSqrtRatio(sqrtPrice)
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
	t.Log("\n## Tick Math Runtime Metrics Results\n")
	t.Log("| Function | Iterations | Duration (ns) | Alloc Delta (bytes) |")
	t.Log("|----------|------------|---------------|---------------------|")
	for _, result := range results {
		t.Logf("| %s | %d | %d | %d |", result.Name, result.Iterations, result.DurationNs, result.AllocDelta)
	}
}