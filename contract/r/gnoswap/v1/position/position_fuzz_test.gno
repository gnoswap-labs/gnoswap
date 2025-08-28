package position

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/gnoswap/fuzz"
	"gno.land/r/gnoswap/v1/gnft"
)

type TickRange struct {
	minLower    int32
	maxLower    int32
	minUpper    int32
	maxUpper    int32
	description string
}

type AmountRange struct {
	min         string
	max         string
	description string
}

func getFuzzTickRanges() []TickRange {
	return []TickRange{
		{-887200, -100000, 100000, 887200, "extreme wide range"},
		{-10000, -1000, 1000, 10000, "wide range"},
		{-500, -100, 100, 500, "narrow range"},
		{-50, -10, 10, 50, "very narrow range"},
		{-887200, -500000, -100000, -1000, "negative range"},
		{1000, 100000, 500000, 887200, "positive range"},
	}
}

// Common test execution helpers

// executeTestCase executes a test function with error handling and statistics collection
func executeTestCase(t *testing.T, testFunc func(), stats *testStats) {
	defer func() {
		if r := recover(); r != nil {
			stats.actualFailureCount++
			errMsg := "panic"
			if str, ok := r.(string); ok {
				errMsg = str
			}
			stats.errorMessages[errMsg]++
			t.Logf("  → Failed with: %v", r)
		}
	}()

	abortVal := revive(testFunc)
	if abortVal != nil {
		stats.actualFailureCount++
		errMsg := "abort"
		if str, ok := abortVal.(string); ok {
			errMsg = str
		}
		stats.errorMessages[errMsg]++
		t.Logf("  → Failed with abort: %v", abortVal)
	} else {
		stats.actualSuccessCount++
	}
}

// testStats holds statistics for test execution
type testStats struct {
	actualSuccessCount int
	actualFailureCount int
	categoryStats      map[string]int
	errorMessages      map[string]int
}

// newTestStats creates a new testStats instance
func newTestStats() *testStats {
	return &testStats{
		categoryStats: make(map[string]int),
		errorMessages: make(map[string]int),
	}
}

// printTestStatistics prints the test execution statistics
func printTestStatistics(t *testing.T, testName string, totalIterations int, stats *testStats) {
	t.Logf("\n=== %s Fuzz Test Statistics ===", testName)
	t.Logf("Total iterations: %d", totalIterations)
	t.Logf("Actual successes: %d (%.1f%%)", stats.actualSuccessCount, float64(stats.actualSuccessCount)/float64(totalIterations)*100)
	t.Logf("Actual failures: %d (%.1f%%)", stats.actualFailureCount, float64(stats.actualFailureCount)/float64(totalIterations)*100)

	t.Logf("\n=== Category Distribution ===")
	for cat, count := range stats.categoryStats {
		t.Logf("%s: %d (%.1f%%)", cat, count, float64(count)/float64(totalIterations)*100)
	}

	t.Logf("\n=== Error Messages ===")
	for msg, count := range stats.errorMessages {
		t.Logf("%s: %d", msg, count)
	}
}

// buildWeightedCategories creates a weighted category selection slice
func buildWeightedCategories(categories []struct {
	name   string
	weight int
}) []string {
	weightedCategories := []string{}
	for _, cat := range categories {
		for i := 0; i < cat.weight; i++ {
			weightedCategories = append(weightedCategories, cat.name)
		}
	}
	return weightedCategories
}

func getFuzzAmountRanges() []AmountRange {
	return []AmountRange{
		{"1", "1000", "dust amounts"},
		{"1000", "100000", "small amounts"},
		{"100000", "10000000", "medium amounts"},
		{"10000000", "1000000000", "large amounts"},
		{"1000000000", "100000000000", "whale amounts"},
	}
}

func getFuzzValidFees() []uint32 {
	return []uint32{100, 500, 3000, 10000}
}

func getFuzzTokenPaths() []string {
	return []string{
		barPath,
		fooPath,
		gnsPath,
		"gno.land/r/demo/wugnot",
		"gno.land/r/test/token1",
		"gno.land/r/test/token2",
	}
}

func getFuzzTestAddresses() []std.Address {
	return []std.Address{
		alice,
		adminAddr,
		testutils.TestAddress("bob"),
		testutils.TestAddress("charlie"),
	}
}

// createAmountGenerator returns a function that generates random amounts within specified ranges
func createAmountGenerator(seedMgr *fuzz.SeedManager) func(int) string {
	return func(rangeIdx int) string {
		ranges := getFuzzAmountRanges()
		if rangeIdx < 0 || rangeIdx >= len(ranges) {
			rangeIdx = seedMgr.CreateIntGenerator(0, len(ranges)-1).Generate().(int)
		}

		switch rangeIdx {
		case 0:
			return strconv.Itoa(seedMgr.CreateIntGenerator(1, 1000).Generate().(int))
		case 1:
			return strconv.Itoa(seedMgr.CreateIntGenerator(1000, 100000).Generate().(int))
		case 2:
			return strconv.Itoa(seedMgr.CreateIntGenerator(100000, 10000000).Generate().(int))
		case 3:
			return strconv.Itoa(seedMgr.CreateIntGenerator(10000000, 1000000000).Generate().(int))
		case 4:
			return strconv.Itoa(seedMgr.CreateIntGenerator(1000000000, 2000000000).Generate().(int))
		default:
			return "1000000"
		}
	}
}

func TestFuzzMint(t *testing.T) {
	// Initialize seed manager for random data generation
	seedMgr := fuzz.NewSeedManager()

	type MintTestCase struct {
		token0     string
		token1     string
		fee        uint32
		tickLower  int32
		tickUpper  int32
		amount0    string
		amount1    string
		minAmount0 string
		minAmount1 string
		deadline   int64
		mintTo     std.Address
		caller     std.Address
		category   string
	}

	// Use shared fuzzing utilities
	tickRanges := getFuzzTickRanges()
	amountRanges := getFuzzAmountRanges()
	validFees := getFuzzValidFees()
	tokenPaths := getFuzzTokenPaths()
	testAddresses := getFuzzTestAddresses()
	generateAmountInRange := createAmountGenerator(seedMgr)

	// Generate test case based on category
	generateMintTestCase := func(category string) MintTestCase {
		var tc MintTestCase
		tc.category = category

		switch category {
		case "valid_standard":
			// Standard valid mint cases
			tc.token0 = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1 = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			// Ensure different tokens
			for tc.token0 == tc.token1 {
				tc.token1 = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			}
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]

			// Generate valid tick range
			tickRange := tickRanges[seedMgr.CreateIntGenerator(0, len(tickRanges)-1).Generate().(int)]
			tc.tickLower = tickRange.minLower + int32(seedMgr.CreateIntGenerator(0, int(tickRange.maxLower-tickRange.minLower)).Generate().(int))
			tc.tickUpper = tickRange.minUpper + int32(seedMgr.CreateIntGenerator(0, int(tickRange.maxUpper-tickRange.minUpper)).Generate().(int))

			// Generate amounts
			amountIdx := seedMgr.CreateIntGenerator(0, len(amountRanges)-1).Generate().(int)
			tc.amount0 = generateAmountInRange(amountIdx)
			tc.amount1 = generateAmountInRange(amountIdx)

			// Min amounts are slightly less than desired amounts
			amount0Val, _ := strconv.ParseInt(tc.amount0, 10, 64)
			amount1Val, _ := strconv.ParseInt(tc.amount1, 10, 64)
			tc.minAmount0 = strconv.FormatInt(amount0Val*9/10, 10)
			tc.minAmount1 = strconv.FormatInt(amount1Val*9/10, 10)

			tc.deadline = time.Now().Add(time.Hour).Unix()
			tc.caller = testAddresses[seedMgr.CreateIntGenerator(0, len(testAddresses)-1).Generate().(int)]
			tc.mintTo = tc.caller // Valid case: mintTo same as caller

		case "edge_ticks":
			// Edge case tick values
			tc.token0 = tokenPaths[0]
			tc.token1 = tokenPaths[1]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]

			edgeCases := []struct{ lower, upper int32 }{
				{-887272, -887200}, // Near minimum
				{887200, 887272},   // Near maximum
				{-100, 100},        // Around zero
				{-887272, 887272},  // Full range
			}
			edge := edgeCases[seedMgr.CreateIntGenerator(0, len(edgeCases)-1).Generate().(int)]
			tc.tickLower = edge.lower
			tc.tickUpper = edge.upper

			tc.amount0 = "1000000"
			tc.amount1 = "1000000"
			tc.minAmount0 = "900000"
			tc.minAmount1 = "900000"
			tc.deadline = time.Now().Add(time.Hour).Unix()
			tc.caller = alice
			tc.mintTo = alice

		case "invalid_tick_order":
			// Invalid tick order (lower > upper)
			tc.token0 = tokenPaths[0]
			tc.token1 = tokenPaths[1]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]

			// Deliberately set tickLower > tickUpper
			tc.tickUpper = int32(seedMgr.CreateIntGenerator(-1000, 1000).Generate().(int))
			tc.tickLower = tc.tickUpper + int32(seedMgr.CreateIntGenerator(1, 1000).Generate().(int))

			tc.amount0 = "1000000"
			tc.amount1 = "1000000"
			tc.minAmount0 = "900000"
			tc.minAmount1 = "900000"
			tc.deadline = time.Now().Add(time.Hour).Unix()
			tc.caller = alice
			tc.mintTo = alice

		case "expired_deadline":
			// Expired deadline
			tc.token0 = tokenPaths[0]
			tc.token1 = tokenPaths[1]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.tickLower = -1000
			tc.tickUpper = 1000
			tc.amount0 = "1000000"
			tc.amount1 = "1000000"
			tc.minAmount0 = "900000"
			tc.minAmount1 = "900000"
			tc.deadline = time.Now().Add(-time.Hour).Unix() // Past deadline
			tc.caller = alice
			tc.mintTo = alice

		case "unauthorized_mintto":
			// Unauthorized mintTo address
			tc.token0 = tokenPaths[0]
			tc.token1 = tokenPaths[1]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.tickLower = -1000
			tc.tickUpper = 1000
			tc.amount0 = "1000000"
			tc.amount1 = "1000000"
			tc.minAmount0 = "900000"
			tc.minAmount1 = "900000"
			tc.deadline = time.Now().Add(time.Hour).Unix()
			tc.caller = alice
			tc.mintTo = adminAddr // Different from caller

		case "extreme_amounts":
			// Extreme amount values
			tc.token0 = tokenPaths[0]
			tc.token1 = tokenPaths[1]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]
			tc.tickLower = -10000
			tc.tickUpper = 10000

			extremeCases := []struct{ amount0, amount1 string }{
				{"1", "1"},                             // Minimum amounts
				{"100000000000000", "100000000000000"}, // Very large amounts
				{"1", "100000000000"},                  // Imbalanced amounts
				{"100000000000", "1"},                  // Reverse imbalanced
			}
			extreme := extremeCases[seedMgr.CreateIntGenerator(0, len(extremeCases)-1).Generate().(int)]
			tc.amount0 = extreme.amount0
			tc.amount1 = extreme.amount1

			// Set min amounts to 0 for extreme cases
			tc.minAmount0 = "0"
			tc.minAmount1 = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()
			tc.caller = alice
			tc.mintTo = alice

		default:
			// Random mix
			tc.token0 = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.token1 = tokenPaths[seedMgr.CreateIntGenerator(0, len(tokenPaths)-1).Generate().(int)]
			tc.fee = validFees[seedMgr.CreateIntGenerator(0, len(validFees)-1).Generate().(int)]

			// Random tick range (may be invalid)
			tc.tickLower = int32(seedMgr.CreateIntGenerator(-887272, 887272).Generate().(int))
			tc.tickUpper = int32(seedMgr.CreateIntGenerator(-887272, 887272).Generate().(int))

			amountIdx := seedMgr.CreateIntGenerator(0, len(amountRanges)-1).Generate().(int)
			tc.amount0 = generateAmountInRange(amountIdx)
			tc.amount1 = generateAmountInRange(amountIdx)
			tc.minAmount0 = "0"
			tc.minAmount1 = "0"

			// Random deadline (may be expired)
			if seedMgr.CreateBoolGenerator().Generate().(bool) {
				tc.deadline = time.Now().Add(time.Hour).Unix()
			} else {
				tc.deadline = time.Now().Add(-time.Hour).Unix()
			}

			tc.caller = testAddresses[seedMgr.CreateIntGenerator(0, len(testAddresses)-1).Generate().(int)]
			tc.mintTo = testAddresses[seedMgr.CreateIntGenerator(0, len(testAddresses)-1).Generate().(int)]
		}

		return tc
	}

	// Test categories with weights
	categories := []struct {
		name   string
		weight int
	}{
		{"valid_standard", 30},
		{"edge_ticks", 15},
		{"invalid_tick_order", 15},
		{"expired_deadline", 10},
		{"unauthorized_mintto", 10},
		{"extreme_amounts", 10},
		{"random", 10},
	}

	// Build weighted category selection
	weightedCategories := buildWeightedCategories(categories)

	// Set up test environment once
	initPositionTest(t)
	testing.SetRealm(adminRealm)

	const totalIterations = 20 // Reduced for actual execution
	stats := newTestStats()

	for i := 0; i < totalIterations; i++ {
		// Select category
		catIdx := seedMgr.CreateIntGenerator(0, len(weightedCategories)-1).Generate().(int)
		category := weightedCategories[catIdx]
		stats.categoryStats[category]++

		tc := generateMintTestCase(category)

		t.Logf("Test case %d [%s]: tokens=(%s,%s) fee=%d ticks=(%d,%d) amounts=(%s,%s)",
			i, tc.category, tc.token0, tc.token1, tc.fee, tc.tickLower, tc.tickUpper,
			tc.amount0, tc.amount1)

		// Execute the actual function call
		setupPoolAndApprovals(t, true)

		executeTestCase(t, func() {
			testing.SetRealm(std.NewUserRealm(tc.caller))

			positionId, liquidity, amount0, amount1 := Mint(
				cross,
				tc.token0,
				tc.token1,
				tc.fee,
				tc.tickLower,
				tc.tickUpper,
				tc.amount0,
				tc.amount1,
				tc.minAmount0,
				tc.minAmount1,
				tc.deadline,
				tc.mintTo,
				tc.caller,
				"",
			)
			t.Logf("  → Success: posId=%d, liquidity=%s, amounts=(%s,%s)",
				positionId, liquidity, amount0, amount1)
		}, stats)

		// Reset for next iteration
		testing.SetRealm(adminRealm)
	}
	printTestStatistics(t, "Mint", totalIterations, stats)
}

func TestFuzzIncreaseLiquidity(t *testing.T) {
	// Initialize seed manager
	seedMgr := fuzz.NewSeedManager()

	// First, set up a pool and create a base position for testing
	initPositionTest(t)
	testing.SetRealm(adminRealm)
	setupPoolAndApprovals(t, true)

	// Create a base position that we'll use for increase liquidity tests
	basePositionId := seedPosition(t, "1000000", "1000000")

	type IncreaseLiquidityTestCase struct {
		positionId     uint64
		amount0Desired string
		amount1Desired string
		amount0Min     string
		amount1Min     string
		deadline       int64
		category       string
	}

	// Use shared utilities
	generateAmountInRange := createAmountGenerator(seedMgr)

	generateIncreaseLiquidityTestCase := func(category string, existingPositionId uint64) IncreaseLiquidityTestCase {
		var tc IncreaseLiquidityTestCase
		tc.category = category

		switch category {
		case "valid_standard":
			// Standard valid increase
			tc.positionId = existingPositionId
			amountIdx := seedMgr.CreateIntGenerator(1, 3).Generate().(int) // Use smaller amounts for testing
			tc.amount0Desired = generateAmountInRange(amountIdx)
			tc.amount1Desired = generateAmountInRange(amountIdx)

			amount0Val, _ := strconv.ParseInt(tc.amount0Desired, 10, 64)
			amount1Val, _ := strconv.ParseInt(tc.amount1Desired, 10, 64)
			tc.amount0Min = strconv.FormatInt(amount0Val*8/10, 10)
			tc.amount1Min = strconv.FormatInt(amount1Val*8/10, 10)
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "expired_deadline":
			// Expired deadline
			tc.positionId = existingPositionId
			tc.amount0Desired = "1000000"
			tc.amount1Desired = "1000000"
			tc.amount0Min = "900000"
			tc.amount1Min = "900000"
			tc.deadline = time.Now().Add(-time.Hour).Unix()

		case "non_existent_position":
			// Non-existent position ID
			tc.positionId = uint64(seedMgr.CreateIntGenerator(999, 9999).Generate().(int))
			tc.amount0Desired = "1000000"
			tc.amount1Desired = "1000000"
			tc.amount0Min = "900000"
			tc.amount1Min = "900000"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "invalid_amounts":
			// Invalid amount strings
			tc.positionId = existingPositionId
			invalidAmounts := []string{"invalid", "-1000", "0"}
			tc.amount0Desired = invalidAmounts[seedMgr.CreateIntGenerator(0, len(invalidAmounts)-1).Generate().(int)]
			tc.amount1Desired = "1000000"
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		default:
			// Random
			tc.positionId = existingPositionId
			amountIdx := seedMgr.CreateIntGenerator(1, 3).Generate().(int)
			tc.amount0Desired = generateAmountInRange(amountIdx)
			tc.amount1Desired = generateAmountInRange(amountIdx)
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()
		}

		return tc
	}

	// Test categories
	categories := []struct {
		name   string
		weight int
	}{
		{"valid_standard", 40},
		{"expired_deadline", 20},
		{"non_existent_position", 20},
		{"invalid_amounts", 20},
	}

	// Build weighted categories
	weightedCategories := buildWeightedCategories(categories)

	const totalIterations = 20 // Reduced for actual execution
	stats := newTestStats()

	for i := 0; i < totalIterations; i++ {
		catIdx := seedMgr.CreateIntGenerator(0, len(weightedCategories)-1).Generate().(int)
		category := weightedCategories[catIdx]
		stats.categoryStats[category]++

		tc := generateIncreaseLiquidityTestCase(category, basePositionId)

		t.Logf("Test case %d [%s]: posId=%d amounts=(%s,%s)",
			i, tc.category, tc.positionId, tc.amount0Desired, tc.amount1Desired)

		// Skip approval for non-existent positions as it will fail before we test IncreaseLiquidity
		if tc.category != "non_existent_position" {
			// Approve tokens for the position
			gnft.Approve(cross, posRealm.Address(), positionIdFrom(tc.positionId))
		}

		executeTestCase(t, func() {
			_, liquidity, amount0, amount1, _ := IncreaseLiquidity(
				cross,
				tc.positionId,
				tc.amount0Desired,
				tc.amount1Desired,
				tc.amount0Min,
				tc.amount1Min,
				tc.deadline,
			)
			t.Logf("  → Success: liquidity=%s, amounts=(%s,%s)", liquidity, amount0, amount1)
		}, stats)
	}
	printTestStatistics(t, "IncreaseLiquidity", totalIterations, stats)
}

func TestFuzzDecreaseLiquidity(t *testing.T) {
	// Initialize seed manager
	seedMgr := fuzz.NewSeedManager()

	// Set up pool and create positions with liquidity
	initPositionTest(t)
	testing.SetRealm(adminRealm)
	setupPoolAndApprovals(t, true)

	// Create a position with substantial liquidity for testing
	basePositionId := seedPosition(t, "10000000", "10000000")

	// Get the actual liquidity of the position
	position := MustGetPosition(basePositionId)
	actualLiquidity := position.liquidity.ToString()

	type DecreaseLiquidityTestCase struct {
		positionId        uint64
		liquidityToRemove string
		amount0Min        string
		amount1Min        string
		deadline          int64
		unwrapResult      bool
		category          string
	}

	// Generate liquidity percentages based on actual position liquidity
	generateLiquidityPercentage := func(pct int) string {
		liquidity, _ := strconv.ParseInt(actualLiquidity, 10, 64)
		return strconv.FormatInt(liquidity*int64(pct)/100, 10)
	}

	generateDecreaseLiquidityTestCase := func(category string, existingPositionId uint64) DecreaseLiquidityTestCase {
		var tc DecreaseLiquidityTestCase
		tc.category = category
		tc.positionId = existingPositionId
		tc.unwrapResult = false // Keep it false for simpler testing

		switch category {
		case "valid_partial":
			// Partial liquidity removal (10-50%)
			percentages := []int{10, 25, 50}
			pct := percentages[seedMgr.CreateIntGenerator(0, len(percentages)-1).Generate().(int)]
			tc.liquidityToRemove = generateLiquidityPercentage(pct)
			tc.amount0Min = "0" // No slippage protection for testing
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "valid_full":
			// Full liquidity removal (100%)
			tc.liquidityToRemove = actualLiquidity
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "zero_liquidity":
			// Zero liquidity (invalid)
			tc.liquidityToRemove = "0"
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "excess_liquidity":
			// More than available liquidity
			liquidity, _ := strconv.ParseInt(actualLiquidity, 10, 64)
			tc.liquidityToRemove = strconv.FormatInt(liquidity*2, 10)
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()

		case "expired_deadline":
			// Expired deadline
			tc.liquidityToRemove = generateLiquidityPercentage(10)
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(-time.Hour).Unix()

		default:
			// Random partial removal
			pct := seedMgr.CreateIntGenerator(1, 90).Generate().(int)
			tc.liquidityToRemove = generateLiquidityPercentage(pct)
			tc.amount0Min = "0"
			tc.amount1Min = "0"
			tc.deadline = time.Now().Add(time.Hour).Unix()
		}

		return tc
	}

	// Test categories
	categories := []struct {
		name   string
		weight int
	}{
		{"valid_partial", 30},
		{"valid_full", 10},
		{"zero_liquidity", 20},
		{"excess_liquidity", 20},
		{"expired_deadline", 20},
	}

	// Build weighted categories
	weightedCategories := buildWeightedCategories(categories)

	const totalIterations = 20 // Reduced for actual execution
	stats := newTestStats()

	for i := 0; i < totalIterations; i++ {
		catIdx := seedMgr.CreateIntGenerator(0, len(weightedCategories)-1).Generate().(int)
		category := weightedCategories[catIdx]
		stats.categoryStats[category]++

		tc := generateDecreaseLiquidityTestCase(category, basePositionId)

		t.Logf("Test case %d [%s]: posId=%d liquidity=%s",
			i, tc.category, tc.positionId, tc.liquidityToRemove)

		// Approve NFT for the position contract
		gnft.Approve(cross, posRealm.Address(), positionIdFrom(tc.positionId))

		// Execute the actual function call
		executeTestCase(t, func() {
			_, liquidity, fee0, fee1, amount0, amount1, _ := DecreaseLiquidity(
				cross,
				tc.positionId,
				tc.liquidityToRemove,
				tc.amount0Min,
				tc.amount1Min,
				tc.deadline,
				tc.unwrapResult,
			)
			t.Logf("  → Success: liquidity=%s, amounts=(%s,%s), fees=(%s,%s)",
				liquidity, amount0, amount1, fee0, fee1)
		}, stats)

		// For full liquidity removal test, recreate position for next iteration
		if category == "valid_full" && i < totalIterations-1 {
			basePositionId = seedPosition(t, "10000000", "10000000")
			position = MustGetPosition(basePositionId)
			actualLiquidity = position.liquidity.ToString()
		}
	}
	printTestStatistics(t, "DecreaseLiquidity", totalIterations, stats)
}
