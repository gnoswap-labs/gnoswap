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

// Test data structures
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

// TestContext holds common test resources
type TestContext struct {
	seedMgr       *fuzz.SeedManager
	tickRanges    []TickRange
	amountRanges  []AmountRange
	validFees     []uint32
	tokenPaths    []string
	testAddresses []std.Address
}

// NewTestContext creates a new test context with all common test data
func NewTestContext() *TestContext {
	return &TestContext{
		seedMgr: fuzz.NewSeedManager(),
		tickRanges: []TickRange{
			{-887200, -100000, 100000, 887200, "extreme wide range"},
			{-10000, -1000, 1000, 10000, "wide range"},
			{-500, -100, 100, 500, "narrow range"},
			{-50, -10, 10, 50, "very narrow range"},
			{-887200, -500000, -100000, -1000, "negative range"},
			{1000, 100000, 500000, 887200, "positive range"},
		},
		amountRanges: []AmountRange{
			{"1", "1000", "dust amounts"},
			{"1000", "100000", "small amounts"},
			{"100000", "10000000", "medium amounts"},
			{"10000000", "1000000000", "large amounts"},
			{"1000000000", "100000000000", "whale amounts"},
		},
		validFees:     []uint32{100, 500, 3000, 10000},
		tokenPaths:    []string{barPath, fooPath, gnsPath, "gno.land/r/demo/wugnot", "gno.land/r/test/token1", "gno.land/r/test/token2"},
		testAddresses: []std.Address{alice, adminAddr, testutils.TestAddress("bob"), testutils.TestAddress("charlie")},
	}
}

// Helper methods for TestContext
func (tc *TestContext) RandomInt(min, max int) int {
	return tc.seedMgr.CreateIntGenerator(min, max).Generate().(int)
}

func (tc *TestContext) RandomBool() bool {
	return tc.seedMgr.CreateBoolGenerator().Generate().(bool)
}

func (tc *TestContext) GenerateAmount(rangeIdx int) string {
	if rangeIdx < 0 || rangeIdx >= len(tc.amountRanges) {
		rangeIdx = tc.RandomInt(0, len(tc.amountRanges)-1)
	}

	switch rangeIdx {
	case 0:
		return strconv.Itoa(tc.RandomInt(1, 1000))
	case 1:
		return strconv.Itoa(tc.RandomInt(1000, 100000))
	case 2:
		return strconv.Itoa(tc.RandomInt(100000, 10000000))
	case 3:
		return strconv.Itoa(tc.RandomInt(10000000, 1000000000))
	case 4:
		return strconv.Itoa(tc.RandomInt(1000000000, 2000000000))
	default:
		return "1000000"
	}
}

func (tc *TestContext) RandomTokenPair() (string, string) {
	token0 := tc.tokenPaths[tc.RandomInt(0, len(tc.tokenPaths)-1)]
	token1 := tc.tokenPaths[tc.RandomInt(0, len(tc.tokenPaths)-1)]
	for token0 == token1 {
		token1 = tc.tokenPaths[tc.RandomInt(0, len(tc.tokenPaths)-1)]
	}
	return token0, token1
}

func (tc *TestContext) RandomFee() uint32 {
	return tc.validFees[tc.RandomInt(0, len(tc.validFees)-1)]
}

func (tc *TestContext) RandomAddress() std.Address {
	return tc.testAddresses[tc.RandomInt(0, len(tc.testAddresses)-1)]
}

func (tc *TestContext) RandomTickRange(rangeIdx int) (int32, int32) {
	if rangeIdx < 0 || rangeIdx >= len(tc.tickRanges) {
		rangeIdx = tc.RandomInt(0, len(tc.tickRanges)-1)
	}
	tickRange := tc.tickRanges[rangeIdx]
	tickLower := tickRange.minLower + int32(tc.RandomInt(0, int(tickRange.maxLower-tickRange.minLower)))
	tickUpper := tickRange.minUpper + int32(tc.RandomInt(0, int(tickRange.maxUpper-tickRange.minUpper)))
	return tickLower, tickUpper
}

// FuzzTestRunner manages the execution of fuzz tests
type FuzzTestRunner struct {
	t               *testing.T
	testName        string
	categories      []TestCategory
	totalIterations int
	stats           *testStats
}

type TestCategory struct {
	Name   string
	Weight int
}

// NewFuzzTestRunner creates a new test runner
func NewFuzzTestRunner(t *testing.T, testName string, categories []TestCategory, iterations int) *FuzzTestRunner {
	return &FuzzTestRunner{
		t:               t,
		testName:        testName,
		categories:      categories,
		totalIterations: iterations,
		stats:           newTestStats(),
	}
}

// Run executes the fuzz test
func (r *FuzzTestRunner) Run(generateTestCase func(string, *TestContext) any, executeTest func(any)) {
	ctx := NewTestContext()
	weightedCategories := r.buildWeightedCategories()

	for i := 0; i < r.totalIterations; i++ {
		// Select category
		category := weightedCategories[ctx.RandomInt(0, len(weightedCategories)-1)]
		r.stats.categoryStats[category]++

		// Generate and execute test case
		testCase := generateTestCase(category, ctx)
		r.executeTestCase(func() {
			executeTest(testCase)
		})
	}

	r.printStatistics()
}

func (r *FuzzTestRunner) buildWeightedCategories() []string {
	weighted := []string{}
	for _, cat := range r.categories {
		for i := 0; i < cat.Weight; i++ {
			weighted = append(weighted, cat.Name)
		}
	}
	return weighted
}

func (r *FuzzTestRunner) executeTestCase(testFunc func()) {
	defer func() {
		if recoverVal := recover(); recoverVal != nil {
			r.stats.actualFailureCount++
			errMsg := "panic"
			if str, ok := recoverVal.(string); ok {
				errMsg = str
			}
			r.stats.errorMessages[errMsg]++
			r.t.Logf("  → Failed with: %v", recoverVal)
		}
	}()

	abortVal := revive(testFunc)
	if abortVal != nil {
		r.stats.actualFailureCount++
		errMsg := "abort"
		if str, ok := abortVal.(string); ok {
			errMsg = str
		}
		r.stats.errorMessages[errMsg]++
		r.t.Logf("  → Failed with abort: %v", abortVal)
	} else {
		r.stats.actualSuccessCount++
	}
}

func (r *FuzzTestRunner) printStatistics() {
	r.t.Logf("\n=== %s Fuzz Test Statistics ===", r.testName)
	r.t.Logf("Total iterations: %d", r.totalIterations)
	r.t.Logf("Actual successes: %d (%.1f%%)", r.stats.actualSuccessCount, float64(r.stats.actualSuccessCount)/float64(r.totalIterations)*100)
	r.t.Logf("Actual failures: %d (%.1f%%)", r.stats.actualFailureCount, float64(r.stats.actualFailureCount)/float64(r.totalIterations)*100)

	r.t.Logf("\n=== Category Distribution ===")
	for cat, count := range r.stats.categoryStats {
		r.t.Logf("%s: %d (%.1f%%)", cat, count, float64(count)/float64(r.totalIterations)*100)
	}

	r.t.Logf("\n=== Error Messages ===")
	for msg, count := range r.stats.errorMessages {
		r.t.Logf("%s: %d", msg, count)
	}
}

// testStats remains the same
type testStats struct {
	actualSuccessCount int
	actualFailureCount int
	categoryStats      map[string]int
	errorMessages      map[string]int
}

func newTestStats() *testStats {
	return &testStats{
		categoryStats: make(map[string]int),
		errorMessages: make(map[string]int),
	}
}

// Mint Test Case
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

func generateMintTestCase(category string, ctx *TestContext) any {
	var tc MintTestCase
	tc.category = category

	switch category {
	case "valid_standard":
		tc.token0, tc.token1 = ctx.RandomTokenPair()
		tc.fee = ctx.RandomFee()
		tc.tickLower, tc.tickUpper = ctx.RandomTickRange(-1)

		amountIdx := ctx.RandomInt(0, len(ctx.amountRanges)-1)
		tc.amount0 = ctx.GenerateAmount(amountIdx)
		tc.amount1 = ctx.GenerateAmount(amountIdx)

		amount0Val, _ := strconv.ParseInt(tc.amount0, 10, 64)
		amount1Val, _ := strconv.ParseInt(tc.amount1, 10, 64)
		tc.minAmount0 = strconv.FormatInt(amount0Val*9/10, 10)
		tc.minAmount1 = strconv.FormatInt(amount1Val*9/10, 10)

		tc.deadline = time.Now().Add(time.Hour).Unix()
		tc.caller = ctx.RandomAddress()
		tc.mintTo = tc.caller

	case "edge_ticks":
		tc.token0, tc.token1 = ctx.tokenPaths[0], ctx.tokenPaths[1]
		tc.fee = ctx.RandomFee()

		edgeCases := []struct{ lower, upper int32 }{
			{-887272, -887200},
			{887200, 887272},
			{-100, 100},
			{-887272, 887272},
		}
		edge := edgeCases[ctx.RandomInt(0, len(edgeCases)-1)]
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
		tc.token0, tc.token1 = ctx.tokenPaths[0], ctx.tokenPaths[1]
		tc.fee = ctx.RandomFee()
		tc.tickUpper = int32(ctx.RandomInt(-1000, 1000))
		tc.tickLower = tc.tickUpper + int32(ctx.RandomInt(1, 1000))
		tc.amount0 = "1000000"
		tc.amount1 = "1000000"
		tc.minAmount0 = "900000"
		tc.minAmount1 = "900000"
		tc.deadline = time.Now().Add(time.Hour).Unix()
		tc.caller = alice
		tc.mintTo = alice

	case "expired_deadline":
		tc.token0, tc.token1 = ctx.tokenPaths[0], ctx.tokenPaths[1]
		tc.fee = ctx.RandomFee()
		tc.tickLower = -1000
		tc.tickUpper = 1000
		tc.amount0 = "1000000"
		tc.amount1 = "1000000"
		tc.minAmount0 = "900000"
		tc.minAmount1 = "900000"
		tc.deadline = time.Now().Add(-time.Hour).Unix()
		tc.caller = alice
		tc.mintTo = alice

	case "unauthorized_mintto":
		tc.token0, tc.token1 = ctx.tokenPaths[0], ctx.tokenPaths[1]
		tc.fee = ctx.RandomFee()
		tc.tickLower = -1000
		tc.tickUpper = 1000
		tc.amount0 = "1000000"
		tc.amount1 = "1000000"
		tc.minAmount0 = "900000"
		tc.minAmount1 = "900000"
		tc.deadline = time.Now().Add(time.Hour).Unix()
		tc.caller = alice
		tc.mintTo = adminAddr

	case "extreme_amounts":
		tc.token0, tc.token1 = ctx.tokenPaths[0], ctx.tokenPaths[1]
		tc.fee = ctx.RandomFee()
		tc.tickLower = -10000
		tc.tickUpper = 10000

		extremeCases := []struct{ amount0, amount1 string }{
			{"1", "1"},
			{"100000000000000", "100000000000000"},
			{"1", "100000000000"},
			{"100000000000", "1"},
		}
		extreme := extremeCases[ctx.RandomInt(0, len(extremeCases)-1)]
		tc.amount0 = extreme.amount0
		tc.amount1 = extreme.amount1
		tc.minAmount0 = "0"
		tc.minAmount1 = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()
		tc.caller = alice
		tc.mintTo = alice

	default:
		tc.token0, tc.token1 = ctx.RandomTokenPair()
		tc.fee = ctx.RandomFee()
		tc.tickLower = int32(ctx.RandomInt(-887272, 887272))
		tc.tickUpper = int32(ctx.RandomInt(-887272, 887272))

		amountIdx := ctx.RandomInt(0, len(ctx.amountRanges)-1)
		tc.amount0 = ctx.GenerateAmount(amountIdx)
		tc.amount1 = ctx.GenerateAmount(amountIdx)
		tc.minAmount0 = "0"
		tc.minAmount1 = "0"

		if ctx.RandomBool() {
			tc.deadline = time.Now().Add(time.Hour).Unix()
		} else {
			tc.deadline = time.Now().Add(-time.Hour).Unix()
		}

		tc.caller = ctx.RandomAddress()
		tc.mintTo = ctx.RandomAddress()
	}

	return tc
}

func TestFuzzMint(t *testing.T) {
	initPositionTest(t)
	testing.SetRealm(adminRealm)

	categories := []TestCategory{
		{"valid_standard", 30},
		{"edge_ticks", 15},
		{"invalid_tick_order", 15},
		{"expired_deadline", 10},
		{"unauthorized_mintto", 10},
		{"extreme_amounts", 10},
		{"random", 10},
	}

	runner := NewFuzzTestRunner(t, "Mint", categories, 20)
	runner.Run(generateMintTestCase, func(testCase any) {
		tc := testCase.(MintTestCase)
		t.Logf("Test case [%s]: tokens=(%s,%s) fee=%d ticks=(%d,%d) amounts=(%s,%s)",
			tc.category, tc.token0, tc.token1, tc.fee, tc.tickLower, tc.tickUpper,
			tc.amount0, tc.amount1)

		setupPoolAndApprovals(t, true)
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

		testing.SetRealm(adminRealm)
	})
}

// IncreaseLiquidity Test Case
type IncreaseLiquidityTestCase struct {
	positionId     uint64
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	category       string
}

func generateIncreaseLiquidityTestCase(category string, ctx *TestContext, existingPositionId uint64) any {
	var tc IncreaseLiquidityTestCase
	tc.category = category

	switch category {
	case "valid_standard":
		tc.positionId = existingPositionId
		amountIdx := ctx.RandomInt(1, 3)
		tc.amount0Desired = ctx.GenerateAmount(amountIdx)
		tc.amount1Desired = ctx.GenerateAmount(amountIdx)

		amount0Val, _ := strconv.ParseInt(tc.amount0Desired, 10, 64)
		amount1Val, _ := strconv.ParseInt(tc.amount1Desired, 10, 64)
		tc.amount0Min = strconv.FormatInt(amount0Val*8/10, 10)
		tc.amount1Min = strconv.FormatInt(amount1Val*8/10, 10)
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "expired_deadline":
		tc.positionId = existingPositionId
		tc.amount0Desired = "1000000"
		tc.amount1Desired = "1000000"
		tc.amount0Min = "900000"
		tc.amount1Min = "900000"
		tc.deadline = time.Now().Add(-time.Hour).Unix()

	case "non_existent_position":
		tc.positionId = uint64(ctx.RandomInt(999, 9999))
		tc.amount0Desired = "1000000"
		tc.amount1Desired = "1000000"
		tc.amount0Min = "900000"
		tc.amount1Min = "900000"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "invalid_amounts":
		tc.positionId = existingPositionId
		invalidAmounts := []string{"invalid", "-1000", "0"}
		tc.amount0Desired = invalidAmounts[ctx.RandomInt(0, len(invalidAmounts)-1)]
		tc.amount1Desired = "1000000"
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	default:
		tc.positionId = existingPositionId
		amountIdx := ctx.RandomInt(1, 3)
		tc.amount0Desired = ctx.GenerateAmount(amountIdx)
		tc.amount1Desired = ctx.GenerateAmount(amountIdx)
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()
	}

	return tc
}

func TestFuzzIncreaseLiquidity(t *testing.T) {
	initPositionTest(t)
	testing.SetRealm(adminRealm)
	setupPoolAndApprovals(t, true)

	basePositionId := seedPosition(t, "1000000", "1000000")

	categories := []TestCategory{
		{"valid_standard", 40},
		{"expired_deadline", 20},
		{"non_existent_position", 20},
		{"invalid_amounts", 20},
	}

	runner := NewFuzzTestRunner(t, "IncreaseLiquidity", categories, 20)

	ctx := NewTestContext()
	runner.Run(func(category string, _ *TestContext) any {
		return generateIncreaseLiquidityTestCase(category, ctx, basePositionId)
	}, func(testCase any) {
		tc := testCase.(IncreaseLiquidityTestCase)
		t.Logf("Test case [%s]: posId=%d amounts=(%s,%s)",
			tc.category, tc.positionId, tc.amount0Desired, tc.amount1Desired)

		if tc.category != "non_existent_position" {
			gnft.Approve(cross, posRealm.Address(), positionIdFrom(tc.positionId))
		}

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
	})
}

// DecreaseLiquidity Test Case
type DecreaseLiquidityTestCase struct {
	positionId        uint64
	liquidityToRemove string
	amount0Min        string
	amount1Min        string
	deadline          int64
	unwrapResult      bool
	category          string
}

func generateDecreaseLiquidityTestCase(category string, ctx *TestContext, existingPositionId uint64, actualLiquidity string) any {
	var tc DecreaseLiquidityTestCase
	tc.category = category
	tc.positionId = existingPositionId
	tc.unwrapResult = false

	generateLiquidityPercentage := func(pct int) string {
		liquidity, _ := strconv.ParseInt(actualLiquidity, 10, 64)
		return strconv.FormatInt(liquidity*int64(pct)/100, 10)
	}

	switch category {
	case "valid_partial":
		percentages := []int{10, 25, 50}
		pct := percentages[ctx.RandomInt(0, len(percentages)-1)]
		tc.liquidityToRemove = generateLiquidityPercentage(pct)
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "valid_full":
		tc.liquidityToRemove = actualLiquidity
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "zero_liquidity":
		tc.liquidityToRemove = "0"
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "excess_liquidity":
		liquidity, _ := strconv.ParseInt(actualLiquidity, 10, 64)
		tc.liquidityToRemove = strconv.FormatInt(liquidity*2, 10)
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()

	case "expired_deadline":
		tc.liquidityToRemove = generateLiquidityPercentage(10)
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(-time.Hour).Unix()

	default:
		pct := ctx.RandomInt(1, 90)
		tc.liquidityToRemove = generateLiquidityPercentage(pct)
		tc.amount0Min = "0"
		tc.amount1Min = "0"
		tc.deadline = time.Now().Add(time.Hour).Unix()
	}

	return tc
}

func TestFuzzDecreaseLiquidity(t *testing.T) {
	initPositionTest(t)
	testing.SetRealm(adminRealm)
	setupPoolAndApprovals(t, true)

	basePositionId := seedPosition(t, "10000000", "10000000")
	position := MustGetPosition(basePositionId)
	actualLiquidity := position.liquidity.ToString()

	categories := []TestCategory{
		{"valid_partial", 30},
		{"valid_full", 10},
		{"zero_liquidity", 20},
		{"excess_liquidity", 20},
		{"expired_deadline", 20},
	}

	runner := NewFuzzTestRunner(t, "DecreaseLiquidity", categories, 20)

	ctx := NewTestContext()
	currentPositionId := basePositionId
	currentLiquidity := actualLiquidity

	runner.Run(func(category string, _ *TestContext) any {
		return generateDecreaseLiquidityTestCase(category, ctx, currentPositionId, currentLiquidity)
	}, func(testCase any) {
		tc := testCase.(DecreaseLiquidityTestCase)
		t.Logf("Test case [%s]: posId=%d liquidity=%s",
			tc.category, tc.positionId, tc.liquidityToRemove)

		gnft.Approve(cross, posRealm.Address(), positionIdFrom(tc.positionId))

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

		// Recreate position if needed for next iteration
		if tc.category == "valid_full" {
			currentPositionId = seedPosition(t, "10000000", "10000000")
			position := MustGetPosition(currentPositionId)
			currentLiquidity = position.liquidity.ToString()
		}
	})
}
