package int256

import (
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestFromDecimal(t *testing.T) {
	tests := []struct {
		input   string
		wantErr bool
		want    string
	}{
		{"0", false, "0"},
		{"1", false, "1"},
		{"-1", false, "-1"},
		{"123456789", false, "123456789"},
		{"-123456789", false, "-123456789"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819967", false, "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819968", false, "-57896044618658097711785492504343953926634992332820282019728792003956564819968"},
		// overflow cases
		{"57896044618658097711785492504343953926634992332820282019728792003956564819968", true, ""},
		{"-57896044618658097711785492504343953926634992332820282019728792003956564819969", true, ""},
		// invalid inputs
		{"", true, ""},
		{"abc", true, ""},
		{"12.34", true, ""},
	}

	for _, tc := range tests {
		z, err := FromDecimal(tc.input)
		if tc.wantErr {
			if err == nil {
				t.Errorf("FromDecimal(%q) expected error, got nil", tc.input)
			}
			continue
		}
		if err != nil {
			t.Errorf("FromDecimal(%q) unexpected error: %v", tc.input, err)
			continue
		}
		if z.ToString() != tc.want {
			t.Errorf("FromDecimal(%q) = %s, want %s", tc.input, z.ToString(), tc.want)
		}
	}
}

func TestMustFromDecimal(t *testing.T) {
	// Valid cases should not panic
	validCases := []string{
		"0", "1", "-1", "123456789",
		"57896044618658097711785492504343953926634992332820282019728792003956564819967",
	}

	for _, tc := range validCases {
		func() {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("MustFromDecimal(%q) panicked unexpectedly: %v", tc, r)
				}
			}()
			z := MustFromDecimal(tc)
			if z == nil {
				t.Errorf("MustFromDecimal(%q) returned nil", tc)
			}
		}()
	}

	// Invalid cases should panic
	invalidCases := []string{
		"", "abc", "12.34",
		"57896044618658097711785492504343953926634992332820282019728792003956564819968",
	}

	for _, tc := range invalidCases {
		func() {
			defer func() {
				if r := recover(); r == nil {
					t.Errorf("MustFromDecimal(%q) should have panicked", tc)
				}
			}()
			MustFromDecimal(tc)
		}()
	}
}

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

	// Test data
	commonDecimal := "1234567890123456789012345678901234567890"

	tests := []struct {
		name string
		run  func(t *testing.T) MetricResult
	}{
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
			name: "SetString",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "SetString", iterations, func() {
					var target Int
					if _, err := target.SetString(commonDecimal); err != nil {
						t.Fatalf("SetString error: %v", err)
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
			name: "MaxInt256",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "MaxInt256", iterations, func() {
					MaxInt256()
				})
			},
		},
		{
			name: "MinInt256",
			run: func(t *testing.T) MetricResult {
				return runMetric(t, "MinInt256", iterations, func() {
					MinInt256()
				})
			},
		},
		{
			name: "ToString",
			run: func(t *testing.T) MetricResult {
				largeInt := MustFromDecimal("57896044618658097711785492504343953926634992332820282019728792003956564819967") // max int256
				return runMetric(t, "ToString", iterations, func() {
					_ = largeInt.ToString()
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
