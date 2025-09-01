package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/fuzz"
)

func TestGetPoolPath(t *testing.T) {
	path := GetPoolPath(barTokenPath, fooTokenPath, 500)
	expected := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	if path != expected {
		t.Errorf("Expected path %s, got %s", expected, path)
	}

	path = GetPoolPath(fooTokenPath, barTokenPath, 500)
	if path != expected {
		t.Errorf("Expected tokens to be sorted, expected %s, got %s", expected, path)
	}
}

func TestTickSpacingMap(t *testing.T) {
	tests := []struct {
		fee         uint32
		tickSpacing int32
	}{
		{100, 1},     // 0.01%
		{500, 10},    // 0.05%
		{3000, 60},   // 0.3%
		{10000, 200}, // 1%
	}

	for _, tt := range tests {
		spacing := GetFeeAmountTickSpacing(tt.fee)
		if spacing != tt.tickSpacing {
			t.Errorf("For fee %d, expected tick spacing %d, got %d",
				tt.fee, tt.tickSpacing, spacing)
		}
	}
}

func TestCreatePool(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		fee         uint32
		sqrtPrice   string
		shouldPanic bool
		panicMsg    string
		inOrder     bool
	}{
		{
			name:       "success - normal token pair",
			token0Path: barPath,
			token1Path: fooPath,
			fee:        3000,
			sqrtPrice:  "4295128740",
		},
		{
			name:       "success - wugnot <> gns pool",
			token0Path: "gno.land/r/demo/wugnot",
			token1Path: "gno.land/r/gnoswap/gns",
			fee:        3000,
			sqrtPrice:  "79228162514264337593543950337",
		},
		{
			name:        "fail - same tokens",
			token0Path:  barPath,
			token1Path:  barPath,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-011] same token used in single pool || expected token0Path(gno.land/r/onbloc/bar) != token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "success - when tokens not in order, reverse order and create pool",
			token0Path:  fooPath,
			token1Path:  bazPath,
			fee:         3000,
			sqrtPrice:   "4295343490",
			shouldPanic: false,
			panicMsg:    "[GNOSWAP-POOL-012] tokens must be in lexicographical order || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/baz)",
			inOrder:     true,
		},
		{
			name:        "fail - pool already exists",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] pool already created || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000) not to exist",
		},
		{
			name:        "fail - invalid fee amount",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         1234,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(1234) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "fail - invalid sqrtPrice (too small)",
			token0Path:  bazPath,
			token1Path:  barPath,
			fee:         3000,
			sqrtPrice:   "0",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-005] out of range for numeric value || sqrtPriceX96(0) is out of range",
		},
	}

	testing.SetRealm(std.NewUserRealm(adminAddr))
	SetPoolCreationFee(cross, 0)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					CreatePool(cross, tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPrice)
				})
			} else {
				CreatePool(cross, tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPrice)

				// verify pool was created correctly
				poolPath := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
				pool := mustGetPool(poolPath)

				// check if GNOT was properly wrapped
				expectedToken0 := tt.token0Path
				expectedToken1 := tt.token1Path
				if tt.inOrder {
					expectedToken0, expectedToken1 = expectedToken1, expectedToken0
				}

				if expectedToken0 == GNOT {
					expectedToken0 = WRAPPED_WUGNOT
				}
				if expectedToken1 == GNOT {
					expectedToken1 = WRAPPED_WUGNOT
				}

				if pool.token0Path != expectedToken0 || pool.token1Path != expectedToken1 {
					t.Errorf("incorrect token paths in pool. got %s,%s want %s,%s",
						pool.token0Path, pool.token1Path, expectedToken0, expectedToken1)
				}
			}
		})
	}

	resetObject(t)
}

func TestGetPool(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func(t *testing.T)
		action      func(t *testing.T) *Pool
		shouldPanic bool
		expected    string
		verifyFn    func(t *testing.T, pool *Pool)
	}{
		{
			name: "Panic - unregistered poolPath",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				SetPoolCreationFee(cross, 0)
			},
			action: func(t *testing.T) *Pool {
				return GetPool(barPath, fooPath, fee500)
			},
			shouldPanic: true,
			expected:    "[GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500) to exist",
		},
		{
			name: "success - get pool (bar:foo:500)",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				SetPoolCreationFee(cross, 0)
				CreatePool(cross, barPath, fooPath, fee500, "4295128740")
			},
			action: func(t *testing.T) *Pool {
				return GetPool(barPath, fooPath, fee500)
			},
			verifyFn: func(t *testing.T, pool *Pool) {
				if pool.token0Path != barPath {
					t.Errorf("expected token0Path %s, got %s", barPath, pool.token0Path)
				}
				if pool.token1Path != fooPath {
					t.Errorf("expected token1Path %s, got %s", fooPath, pool.token1Path)
				}
				if pool.fee != fee500 {
					t.Errorf("expected fee %d, got %d", fee500, pool.fee)
				}
				if pool.slot0.sqrtPriceX96.ToString() != "4295128740" {
					t.Errorf("expected sqrtPriceX96 %s, got %s", "4295128740", pool.slot0.sqrtPriceX96.ToString())
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r == nil {
					if tt.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tt.name)
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tt.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tt.name, r, tt.expected)
						}
					case error:
						if r.(error).Error() != tt.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tt.name, r.(error).Error(), tt.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tt.name, r, tt.expected)
					}
				}
			}()
			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			if tt.shouldPanic {
				tt.action(t)
			}

			if !tt.shouldPanic {
				pool := tt.action(t)
				if tt.verifyFn != nil {
					tt.verifyFn(t, pool)
				}
			}
		})
	}
}

func TestFuzzPoolCreation(t *testing.T) {
	// should generate different seed for each test case
	seedMgr := fuzz.NewSeedManager()

	type PoolTestCase struct {
		token0Path string
		token1Path string
		fee        uint32
		sqrtPrice  string
		category   string // for tracking test case type
	}

	// Price range definitions for better organization
	type PriceRange struct {
		min         string
		max         string
		description string
	}

	priceRanges := []PriceRange{
		{"4295128740", "10000000000000000000", "extreme low prices"},
		{"10000000000000000001", "50000000000000000000000000", "low prices"},
		{"50000000000000000000000001", "100000000000000000000000000000000", "medium prices"},
		{"100000000000000000000000000000001", "1000000000000000000000000000000000000", "high prices"},
		{"1000000000000000000000000000000000001", "1461446703485210103287273052203988822378723970341", "extreme high prices"},
	}

	tokenPaths := []string{
		"gno.land/r/onbloc/bar",
		"gno.land/r/onbloc/foo",
		"gno.land/r/onbloc/baz",
		"gno.land/r/demo/wugnot",
		"gno.land/r/gnoswap/gns",
		"gno.land/r/test/token1",
		"gno.land/r/test/token2",
		"gno.land/r/test/token3",
	}

	// Generate price within a specific range
	generatePriceInRange := func(rangeIdx int) string {
		if rangeIdx < 0 || rangeIdx >= len(priceRanges) {
			rangeIdx = seedMgr.CreateIntGenerator(0, len(priceRanges)-1).Generate().(int)
		}

		switch rangeIdx {
		case 0:
			return "5000000000000000000" // example value in range
		case 1:
			return "25000000000000000000000000"
		case 2:
			return "79228162514264337593543950336" // 1:1 ratio
		case 3:
			return "500000000000000000000000000000000000"
		case 4:
			return "1200000000000000000000000000000000000000"
		default:
			return "79228162514264337593543950336"
		}
	}

	generatePoolTestCase := func(category string) PoolTestCase {
		var tc PoolTestCase
		tc.category = category

		switch category {
		case "valid_standard":
			// Standard valid test cases
			validFees := []uint32{100, 500, 3000, 10000}
			tc.token0Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			// Ensure different tokens
			for tc.token0Path == tc.token1Path {
				tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			}
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.sqrtPrice = generatePriceInRange(seedMgr.CreateIntGenerator(0, len(priceRanges)-1).Generate().(int))

		case "edge_prices":
			// Edge case prices
			edgePrices := []string{
				"4295128740", // MIN_SQRT_RATIO + 1
				"1461446703485210103287273052203988822378723970341", // MAX_SQRT_RATIO - 1
			}
			validFees := []uint32{100, 500, 3000, 10000}
			tc.token0Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			for tc.token0Path == tc.token1Path {
				tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			}
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.sqrtPrice = edgePrices[seedMgr.CreateIntGenerator(0, len(edgePrices)-1).Generate().(int)]

		case "invalid_fee":
			// Invalid fee amounts
			invalidFees := []uint32{0, 50, 1234, 15000, 99999}
			tc.token0Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			for tc.token0Path == tc.token1Path {
				tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			}
			tc.fee = invalidFees[seedMgr.CreateIntGenerator(0, len(invalidFees)-1).Generate().(int)]
			tc.sqrtPrice = generatePriceInRange(2) // valid price

		case "invalid_price":
			// Invalid prices
			invalidPrices := []string{
				"0",
				"1",
				"4295128738", // MIN_SQRT_RATIO - 1
				"1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
				"-1",
				"-79228162514264337593543950336",
			}
			validFees := []uint32{100, 500, 3000, 10000}
			tc.token0Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			for tc.token0Path == tc.token1Path {
				tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			}
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.sqrtPrice = invalidPrices[seedMgr.CreateIntGenerator(0, len(invalidPrices)-1).Generate().(int)]

		case "same_token":
			// Same token pair (invalid)
			validFees := []uint32{100, 500, 3000, 10000}
			tokenIdx := seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)
			tc.token0Path = tokenPaths[tokenIdx]
			tc.token1Path = tokenPaths[tokenIdx] // same token
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.sqrtPrice = generatePriceInRange(2)

		default:
			// Random mix of all possibilities
			allFees := []uint32{0, 50, 100, 500, 1234, 3000, 10000, 15000}
			allPrices := []string{
				"0", "1", "4295128740", "79228162514264337593543950336",
				"1461446703485210103287273052203988822378723970341",
				"1461446703485210103287273052203988822378723970343", "-1",
			}
			tc.token0Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1Path = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.fee = allFees[seedMgr.CreateIntGenerator(0, len(allFees)-1).Generate().(int)]
			tc.sqrtPrice = allPrices[seedMgr.CreateIntGenerator(0, len(allPrices)-1).Generate().(int)]
		}

		return tc
	}

	validatePoolCreation := func(tc PoolTestCase) (bool, string) {
		if tc.token0Path == tc.token1Path {
			return false, "same tokens"
		}

		validFees := map[uint32]bool{100: true, 500: true, 3000: true, 10000: true}
		if !validFees[tc.fee] {
			return false, "invalid fee tier"
		}

		invalidPrices := map[string]bool{
			"0":          true,
			"1":          true,
			"4295128738": true, // MIN_SQRT_RATIO - 1
			"1461446703485210103287273052203988822378723970343": true, // MAX_SQRT_RATIO + 1
			"-1":                             true,
			"-79228162514264337593543950336": true,
		}
		if invalidPrices[tc.sqrtPrice] {
			return false, "invalid sqrt price"
		}

		// Check for negative prices
		if len(tc.sqrtPrice) > 0 && tc.sqrtPrice[0] == '-' {
			return false, "negative sqrt price"
		}

		return true, "valid"
	}

	// Test categories with weights for balanced coverage
	categories := []struct {
		name   string
		weight int
	}{
		{"valid_standard", 30},
		{"edge_prices", 20},
		{"invalid_fee", 15},
		{"invalid_price", 15},
		{"same_token", 10},
		{"random", 10},
	}

	// Build weighted category selection
	weightedCategories := []string{}
	for _, cat := range categories {
		for i := 0; i < cat.weight; i++ {
			weightedCategories = append(weightedCategories, cat.name)
		}
	}

	const totalIterations = 150
	successCount := 0
	failureCount := 0
	categoryStats := make(map[string]int)
	failureReasons := make(map[string]int)

	for i := 0; i < totalIterations; i++ {
		// Select category based on weights
		catIdx := seedMgr.CreateIntGenerator(0, len(weightedCategories)-1).Generate().(int)
		category := weightedCategories[catIdx]
		categoryStats[category]++

		tc := generatePoolTestCase(category)
		shouldSucceed, reason := validatePoolCreation(tc)

		if !shouldSucceed {
			failureReasons[reason]++
		}

		t.Logf("Test case %d [%s] should %s: token0=%s, token1=%s, fee=%d, price=%s (reason: %s)",
			i, tc.category, map[bool]string{true: "succeed", false: "fail"}[shouldSucceed],
			tc.token0Path, tc.token1Path, tc.fee, tc.sqrtPrice, reason)

		var (
			abortVal, panicVal any
			didPanic           bool
		)

		// Use revive to catch cross-realm aborts
		abortVal = revive(func() {
			// Use defer+recover to catch same-realm panics
			defer func() {
				if r := recover(); r != nil {
					didPanic = true
					panicVal = r
				}
			}()

			env := NewPoolTestEnv(t).AsAdmin()

			// try to create pool (success/failure both tested)
			NewPoolBuilder().
				WithTokens(tc.token0Path, tc.token1Path).
				WithFee(tc.fee).
				AtPrice(tc.sqrtPrice).
				Create(env)

			// if it reaches here, it means panic/abort is not occurred
			if !shouldSucceed {
				t.Errorf("Pool creation should have failed but succeeded: %+v", tc)
				return
			}

			// check if pool is created correctly
			assertPoolExists(t, tc.token0Path, tc.token1Path, tc.fee)
			successCount++
			InitPoolTest(t)
		})

		// Check if revive caught an abort
		if abortVal != nil {
			if shouldSucceed {
				t.Errorf("Pool creation should succeed but aborted: %+v, abort: %v", tc, abortVal)
			} else {
				failureCount++ // expected failure
			}
			continue
		}

		// Check if recover caught a panic
		if didPanic {
			if shouldSucceed {
				t.Errorf("Pool creation should succeed but panicked: %+v, panic: %v", tc, panicVal)
			} else {
				failureCount++ // expected failure
			}
		}
	}

	// Print test statistics
	t.Logf("\n=== Fuzz Test Statistics ===")
	t.Logf("Total iterations: %d", totalIterations)
	t.Logf("Successes: %d (%.1f%%)", successCount, float64(successCount)/float64(totalIterations)*100)
	t.Logf("Failures: %d (%.1f%%)", failureCount, float64(failureCount)/float64(totalIterations)*100)

	t.Logf("\n=== Category Distribution ===")
	for cat, count := range categoryStats {
		t.Logf("%s: %d (%.1f%%)", cat, count, float64(count)/float64(totalIterations)*100)
	}

	t.Logf("\n=== Failure Reasons ===")
	for reason, count := range failureReasons {
		t.Logf("%s: %d", reason, count)
	}

	// at least one success case is required
	if successCount == 0 {
		t.Errorf("No successful pool creation cases found - check test data generation")
	}
}
