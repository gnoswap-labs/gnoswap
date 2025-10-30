package v1

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"

	// Fuzzing package
	"gno.land/p/gnoswap/fuzz"
)

// FuzzCreatePoolTest simulates Go's fuzz testing pattern for CreatePool
func TestFuzzCreatePool(t *testing.T) {
	// Create a pool fuzzer
	poolFuzzer := fuzz.NewCreatePoolFuzzer(fuzz.STATELESS)

	// Test corpus - known test cases that should be included
	testCorpus := []fuzz.CreatePoolParams{
		// Valid cases
		{Token0Path: barTokenPath, Token1Path: fooTokenPath, Fee: 3000, SqrtPriceX96: "4295128740"},
		{Token0Path: "gno.land/r/gnoland/wugnot", Token1Path: "gno.land/r/gnoswap/gns", Fee: 3000, SqrtPriceX96: "79228162514264337593543950336"},
		{Token0Path: fooTokenPath, Token1Path: bazTokenPath, Fee: 3000, SqrtPriceX96: "4295343490"},

		// Invalid cases
		{Token0Path: barTokenPath, Token1Path: barTokenPath, Fee: 3000, SqrtPriceX96: "4295128740"}, // Same token
		{Token0Path: barTokenPath, Token1Path: fooTokenPath, Fee: 1234, SqrtPriceX96: "4295128740"}, // Invalid fee
		{Token0Path: bazTokenPath, Token1Path: barTokenPath, Fee: 3000, SqrtPriceX96: "0"},          // Invalid sqrt price
		{Token0Path: "", Token1Path: "", Fee: 0, SqrtPriceX96: ""},                                  // Empty inputs
		{Token0Path: "a", Token1Path: "b", Fee: 100, SqrtPriceX96: "1"},                             // Short invalid paths
	}

	// Run corpus tests first
	for i, params := range testCorpus {
		t.Run(uintToString(i), func(t *testing.T) {
			runCreatePoolFuzzTest(t, params)
		})
	}

	// Run fuzzing with generated inputs
	iterations := 100
	successCount := 0
	failureCount := 0
	errorPatterns := make(map[string]int)

	for i := 0; i < iterations; i++ {
		// Generate random parameters
		params := poolFuzzer.GenerateCreatePoolParams()

		// Run test and track results
		result := runCreatePoolFuzzTestWithResult(t, params)
		if result.success {
			successCount++
		} else {
			failureCount++
			if result.errorCode != "" {
				errorPatterns[result.errorCode]++
			}
		}
	}

	// Report summary
	t.Logf("Fuzz test summary:")
	t.Logf("  Total iterations: %d", iterations)
	t.Logf("  Success: %d (%.2f%%)", successCount, float64(successCount)/float64(iterations)*100)
	t.Logf("  Failures: %d", failureCount)
	t.Logf("  Error patterns:")
	for code, count := range errorPatterns {
		t.Logf("    %s: %d occurrences", code, count)
	}
}

type fuzzResult struct {
	success   bool
	errorCode string
	errorMsg  string
}

var poolErrorPatternMap = map[string]string{
	"[GNOSWAP-POOL-011]":   "POOL-011",   // same token
	"[GNOSWAP-POOL-012]":   "POOL-012",   // token order
	"[GNOSWAP-POOL-003]":   "POOL-003",   // pool exists
	"[GNOSWAP-POOL-002]":   "POOL-002",   // unsupported fee
	"[GNOSWAP-POOL-005]":   "POOL-005",   // out of range
	"[GNOSWAP-COMMON-004]": "COMMON-004", // token not registered
	"[GNOSWAP-COMMON-003]": "COMMON-003", // common out of range
	"strconv.ParseUint":    "PARSE_UINT",
}

func runCreatePoolFuzzTestWithResult(t *testing.T, params fuzz.CreatePoolParams) fuzzResult {
	// Initialize for each test
	initPoolTest(t)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	mockInstanceSetPoolCreationFee(0)

	result := fuzzResult{success: true}

	// Handle panics that occur outside realm boundary crossings.
	defer func() {
		if r := recover(); r != nil {
			panicMsg := uintToString(r)
			if code, ok := classifyCreatePoolError(panicMsg); ok {
				result.success = false
				result.errorCode = code
				result.errorMsg = panicMsg
				return
			}

			t.Errorf("unexpected panic with message: %v", panicMsg)
			result.success = false
			result.errorCode = "UNEXPECTED"
			result.errorMsg = panicMsg
		}
	}()

	// Skip invalid inputs
	if len(params.Token0Path) > 200 || len(params.Token1Path) > 200 || len(params.SqrtPriceX96) > 100 {
		t.Log("input too long")
		return result
	}

	if strings.TrimSpace(params.Token0Path) == "" || strings.TrimSpace(params.Token1Path) == "" {
		t.Log("empty token paths")
		return result
	}

	// Try to create pool while capturing cross-realm aborts.
	abort := revive(func() {
		mockInstanceCreatePool(params.Token0Path, params.Token1Path, params.Fee, params.SqrtPriceX96)
	})
	if abort != nil {
		panicMsg := uintToString(abort)
		if code, ok := classifyCreatePoolError(panicMsg); ok {
			result.success = false
			result.errorCode = code
			result.errorMsg = panicMsg
			return result
		}

		t.Errorf("unexpected abort with message: %v", panicMsg)
		result.success = false
		result.errorCode = "UNEXPECTED"
		result.errorMsg = panicMsg
		return result
	}

	// If no panic, verify pool was created correctly
	poolPath := GetPoolPath(params.Token0Path, params.Token1Path, params.Fee)
	pool := getMockInstance().mustGetPool(poolPath)

	// Verify invariants
	if pool == nil {
		t.Error("pool should not be nil after successful creation")
		result.success = false
		return result
	}

	// Token paths should be set
	if pool.Token0Path() == "" || pool.Token1Path() == "" {
		t.Error("token paths should not be empty")
		result.success = false
		return result
	}

	// Tokens should be in lexicographical order
	if pool.Token0Path() >= pool.Token1Path() {
		t.Errorf("tokens not in lexicographical order: %s >= %s",
			pool.Token0Path(), pool.Token1Path())
		result.success = false
		return result
	}

	// Fee should match
	if pool.Fee() != params.Fee {
		t.Errorf("fee mismatch: got %d, want %d", pool.Fee(), params.Fee)
		result.success = false
		return result
	}

	return result
}

func runCreatePoolFuzzTest(t *testing.T, params fuzz.CreatePoolParams) {
	result := runCreatePoolFuzzTestWithResult(t, params)
	if !result.success && result.errorCode == "UNEXPECTED" {
		t.Fail()
	}
}

// Helper to convert uint to string since ufmt might not be available in tests
func uintToString(v any) string {
	switch val := v.(type) {
	case string:
		return val
	case []byte:
		return string(val)
	case error:
		return val.Error()
	case int:
		return ufmt.Sprintf("%d", val)
	case uint32:
		return ufmt.Sprintf("%d", val)
	case uint64:
		return ufmt.Sprintf("%d", val)
	default:
		return ufmt.Sprintf("%v", val)
	}
}

func classifyCreatePoolError(panicMsg string) (string, bool) {
	for pattern, code := range poolErrorPatternMap {
		if strings.Contains(panicMsg, pattern) {
			return code, true
		}
	}
	return "", false
}

// Test with property-based testing from fuzz package
func TestCreatePoolWithFuzzPackage(t *testing.T) {
	// Test property: Successfully created pools should always have ordered tokens
	poolFuzzer := fuzz.NewCreatePoolFuzzer(fuzz.STATELESS)
	result := fuzz.FuzzWithConfig(
		fuzz.Config{
			Iterations: 50,
			Shrink:     true,
		},
		func(iteration int) bool {
			// Generate fuzz parameters
			poolFuzzer.Reset()
			params := poolFuzzer.GenerateCreatePoolParams()

			// Skip empty inputs
			if params.Token0Path == "" || params.Token1Path == "" || params.SqrtPriceX96 == "" {
				return true
			}

			// Reinitialize state per iteration
			initPoolTest(t)
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			mockInstanceSetPoolCreationFee(0)

			abort := revive(func() {
				mockInstanceCreatePool(params.Token0Path, params.Token1Path, params.Fee, params.SqrtPriceX96)
			})
			if abort != nil {
				panicMsg := uintToString(abort)
				if _, ok := classifyCreatePoolError(panicMsg); ok {
					return true
				}

				t.Logf("unexpected abort during property test (iteration %d): %s", iteration, panicMsg)
				return false
			}

			// If successful, ensure tokens are ordered
			poolPath := GetPoolPath(params.Token0Path, params.Token1Path, params.Fee)
			pool := getMockInstance().mustGetPool(poolPath)

			if pool != nil && pool.Token0Path() >= pool.Token1Path() {
				t.Logf("iteration %d produced unordered token paths: %s >= %s",
					iteration, pool.Token0Path(), pool.Token1Path())
				return false
			}

			return true
		},
	)

	if result.Failed {
		t.Fatalf("property test failed after %d iterations (failing input: %v)",
			result.Iterations, result.FailingInput)
	}
}

// Test specific edge cases found by fuzzing
func TestCreatePoolFuzzEdgeCases(t *testing.T) {
	edgeCases := []struct {
		name        string
		params      fuzz.CreatePoolParams
		expectAbort bool
		abortMsg    string
	}{
		{
			name: "MaxUint32Fee",
			params: fuzz.CreatePoolParams{
				Token0Path:   barTokenPath,
				Token1Path:   fooTokenPath,
				Fee:          4294967295, // max uint32
				SqrtPriceX96: "79228162514264337593543950336",
			},
			expectAbort: true,
			abortMsg:    "[GNOSWAP-POOL-002]",
		},
		{
			name: "VeryLongTokenPath",
			params: fuzz.CreatePoolParams{
				Token0Path:   strings.Repeat("a", 150) + "/token",
				Token1Path:   barTokenPath,
				Fee:          3000,
				SqrtPriceX96: "79228162514264337593543950336",
			},
			expectAbort: true, // rejected because token is unregistered
			abortMsg:    "[GNOSWAP-COMMON-004]",
		},
		{
			name: "NegativeSqrtPrice",
			params: fuzz.CreatePoolParams{
				Token0Path:   barTokenPath,
				Token1Path:   fooTokenPath,
				Fee:          3000,
				SqrtPriceX96: "-79228162514264337593543950336",
			},
			expectAbort: true, // negative price fails during parsing
			abortMsg:    "strconv.ParseUint",
		},
		{
			name: "MaxSqrtPrice",
			params: fuzz.CreatePoolParams{
				Token0Path:   barTokenPath,
				Token1Path:   fooTokenPath,
				Fee:          3000,
				SqrtPriceX96: fuzz.MAX_SQRT_RATIO,
			},
			expectAbort: true, // maximum ratio exceeds supported bounds
			abortMsg:    "[GNOSWAP-COMMON-003]",
		},
	}

	for _, tc := range edgeCases {
		t.Run(tc.name, func(t *testing.T) {
			initPoolTest(t)
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			mockInstanceSetPoolCreationFee(0)

			if tc.expectAbort {
				uassert.AbortsContains(t, tc.abortMsg, func() {
					mockInstanceCreatePool(tc.params.Token0Path, tc.params.Token1Path,
						tc.params.Fee, tc.params.SqrtPriceX96)
				})
			} else {
				abort := revive(func() {
					mockInstanceCreatePool(tc.params.Token0Path, tc.params.Token1Path,
						tc.params.Fee, tc.params.SqrtPriceX96)
				})
				if abort != nil {
					t.Fatalf("unexpected abort: %s", uintToString(abort))
				}
			}
		})
	}
}
