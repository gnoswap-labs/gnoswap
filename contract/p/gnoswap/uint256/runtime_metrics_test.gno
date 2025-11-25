package uint256

import (
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
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

func TestPublicFunctionRuntimeMetrics(t *testing.T) {
	const iterations = 200
	var results []MetricResult

	commonDecimal := "1234567890123456789012345678901234567890"
	setTarget := new(Uint)
	fromTarget := new(Uint)
	mulX := MustFromDecimal("340282366920938463463374607431768211455") // 2^128-1
	mulY := MustFromDecimal("18446744073709551616")                    // 2^64
	dividend := MustFromDecimal("9876543210987654321098765432109876543210")
	divisor := MustFromDecimal("4294967296")

	tests := []struct {
		name string
		run  func(t *testing.T) MetricResult
	}{
		{
			name: "SetFromDecimal",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "SetFromDecimal", iterations, func() {
					if err := setTarget.SetFromDecimal(commonDecimal); err != nil {
						t.Fatalf("SetFromDecimal error: %v", err)
					}
				})
			},
		},
		{
			name: "fromDecimal",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "fromDecimal", iterations, func() {
					if err := fromTarget.fromDecimal(commonDecimal); err != nil {
						t.Fatalf("fromDecimal error: %v", err)
					}
				})
			},
		},
		{
			name: "MustFromDecimal",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "MustFromDecimal", iterations, func() {
					MustFromDecimal(commonDecimal)
				})
			},
		},
		{
			name: "umul",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "umul", iterations, func() {
					umul(mulX, mulY)
				})
			},
		},
		{
			name: "MulOverflow",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "MulOverflow", iterations, func() {
					var target Uint
					if _, overflow := target.MulOverflow(mulX, mulY); overflow {
						t.Fatalf("MulOverflow unexpectedly overflowed")
					}
				})
			},
		},
		{
			name: "umulStep",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "umulStep", iterations, func() {
					umulStep(0x1111111111111111, 0x2222222222222222, 0x3333333333333333, 0x4444444444444444)
				})
			},
		},
		{
			name: "NewUint",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "NewUint", iterations, func() {
					NewUint(1234567890)
				})
			},
		},
		{
			name: "umulHop",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "umulHop", iterations, func() {
					umulHop(0x5555555555555555, 0x6666666666666666, 0x7777777777777777)
				})
			},
		},
		{
			name: "FromDecimal",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "FromDecimal", iterations, func() {
					if _, err := FromDecimal(commonDecimal); err != nil {
						t.Fatalf("FromDecimal error: %v", err)
					}
				})
			},
		},
		{
			name: "SetUint64",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "SetUint64", iterations, func() {
					setTarget.SetUint64(0xFFFFFFFFFFFFFFFF)
				})
			},
		},
		{
			name: "udivrem",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "udivrem", iterations, func() {
					var quotient Uint
					_ = udivrem(quotient[:], dividend[:], divisor)
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
	t.Log("\n## Runtime Metrics Results\n")
	t.Log("| Function | Iterations | Duration (ns) | Alloc Delta (bytes) |")
	t.Log("|----------|------------|---------------|---------------------|")
	for _, result := range results {
		t.Logf("| %s | %d | %d | %d |", result.Name, result.Iterations, result.DurationNs, result.AllocDelta)
	}
}
