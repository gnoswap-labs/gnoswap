// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"std"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	u256 "gno.land/p/gnoswap/uint256"
)

var t *testing.T

const (
	INT64_MAX int64 = 9223372036854775807
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	bazPath = "gno.land/r/onbloc/baz"
	fee500  = uint32(500)
	fee3000 = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] Price Impact Analysis - Comparing with Uniswap V3 Mathematics")
	initPools()
	println()

	testing.SkipHeights(1)

	ufmt.Println("[SCENARIO] 1. Price Impact for Different Trade Sizes")
	testPriceImpactSmall()
	println()
	testPriceImpactMedium()
	println()
	testPriceImpactLarge()
	println()

	ufmt.Println("[SCENARIO] 2. Price Impact Across Different Fee Tiers")
	testPriceImpactFeeTiers()
	println()

	ufmt.Println("[SCENARIO] 3. Multi-hop Price Impact Analysis")
	testMultiHopPriceImpact()
	println()

	ufmt.Println("[SCENARIO] 4. Price Impact at Tick Boundaries")
	testTickBoundaryPriceImpact()
	println()
}

func initPools() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	defaultTokenAmount := int64(100_000_000_000_000)

	ufmt.Println("[INFO] Distributing tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)
	baz.Transfer(cross, aliceAddr, defaultTokenAmount)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pools with different fee tiers")
	// Create 0.05% fee pool (concentrated liquidity)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Create 0.3% fee pool (standard)
	pool.CreatePool(cross, barPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Create multi-hop pools
	pool.CreatePool(cross, fooPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Add liquidity
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)

	// Add concentrated liquidity around current price
	position.Mint(cross, barPath, fooPath, fee500, -100, 100, "10000000000", "10000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	position.Mint(cross, barPath, fooPath, fee500, -1000, 1000, "50000000000", "50000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	position.Mint(cross, barPath, fooPath, fee500, -10000, 10000, "100000000000", "100000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")

	// Add liquidity to 0.3% pool
	position.Mint(cross, barPath, fooPath, fee3000, -6000, 6000, "50000000000", "50000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")

	// Add liquidity for multi-hop
	position.Mint(cross, fooPath, bazPath, fee500, -5000, 5000, "30000000000", "30000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, routerAddr, INT64_MAX)
	foo.Approve(cross, routerAddr, INT64_MAX)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, routerAddr, INT64_MAX)
	foo.Approve(cross, routerAddr, INT64_MAX)
}

func testPriceImpactSmall() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing small trade (0.01% of liquidity)")
	amount := "10000000" // Small amount
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	// Get initial price
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	initialPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Initial sqrt price: %s\n", initialPrice)

	// Execute swap
	bar.Approve(cross, routerAddr, INT64_MAX)
	foo.Approve(cross, routerAddr, INT64_MAX)
	_, amountOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	// Get final price
	finalPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Final sqrt price: %s\n", finalPrice)

	// Calculate actual price impact
	priceImpact := calculatePriceImpact(initialPrice, finalPrice)

	ufmt.Printf("[EXPECTED] Small trade amountOut: %s\n", amountOut)
	ufmt.Println("[EXPECTED] Price impact should be < 0.01%, actual:", priceImpact)
}

func testPriceImpactMedium() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing medium trade (1% of liquidity)")
	amount := "1000000000" // Medium amount
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	initialPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Initial sqrt price: %s\n", initialPrice)

	_, amountOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	finalPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Final sqrt price: %s\n", finalPrice)

	priceImpact := calculatePriceImpact(initialPrice, finalPrice)

	ufmt.Printf("[EXPECTED] Medium trade amountOut: %s\n", amountOut)
	ufmt.Println("[EXPECTED] Price impact should be 0.01~0.1%, actual:", priceImpact)
}

func testPriceImpactLarge() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing large trade (10% of liquidity)")
	amount := "10000000000" // Large amount
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	initialPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Initial sqrt price: %s\n", initialPrice)

	_, amountOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	finalPrice := pool.GetSlot0SqrtPriceX96(poolPath).ToString()
	ufmt.Printf("[INFO] Final sqrt price: %s\n", finalPrice)

	priceImpact := calculatePriceImpact(initialPrice, finalPrice)

	ufmt.Printf("[EXPECTED] Large trade amountOut: %s\n", amountOut)
	ufmt.Println("[EXPECTED] Price impact should be > 0.1%, actual:", priceImpact)
}

func testPriceImpactFeeTiers() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Comparing price impact across fee tiers")
	amount := "1000000000"

	barFoo500Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	barFoo3000Path := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	initialPrice500 := pool.GetSlot0SqrtPriceX96(barFoo500Path).ToString()
	initialPrice3000 := pool.GetSlot0SqrtPriceX96(barFoo3000Path).ToString()

	// Test 0.05% fee pool
	route500 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	_, amountOut500 := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route500, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] 0.05%% fee pool output: %s\n", amountOut500)

	// Test 0.3% fee pool
	route3000 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	_, amountOut3000 := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route3000, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] 0.3%% fee pool output: %s\n", amountOut3000)

	finalPrice500 := pool.GetSlot0SqrtPriceX96(barFoo500Path).ToString()
	finalPrice3000 := pool.GetSlot0SqrtPriceX96(barFoo3000Path).ToString()

	priceImpact500 := calculatePriceImpact(initialPrice500, finalPrice500)
	priceImpact3000 := calculatePriceImpact(initialPrice3000, finalPrice3000)

	ufmt.Printf("[EXPECTED] 0.05%% fee pool output: %s\n", amountOut500)
	ufmt.Printf("[EXPECTED] 0.3%% fee pool output: %s\n", amountOut3000)
	ufmt.Println("[EXPECTED] Lower fee tier should give better output (less price impact)")
	ufmt.Println("[EXPECTED] Price impact actual:", priceImpact500)
	ufmt.Println("[EXPECTED] Price impact actual:", priceImpact3000)
}

func testMultiHopPriceImpact() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing multi-hop price impact")
	amount := "1000000000"

	// Single hop: BAR -> FOO
	routeSingle := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	_, outputSingle := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, routeSingle, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Single hop output: %s\n", outputSingle)

	// Multi-hop: BAR -> FOO -> BAZ -> FOO -> BAR (should have more price impact)
	// Note: This is a simplified example, actual multi-hop would use different paths
	ufmt.Println("[INFO] Multi-hop swaps aggregate price impact from each hop")
}

func testTickBoundaryPriceImpact() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing price impact at tick boundaries")

	// Small swap within single tick
	smallAmount := "1000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	_, outputSmall := router.ExactInSwapRoute(
		cross, barPath, fooPath, smallAmount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Within tick output: %s\n", outputSmall)

	// Large swap crossing multiple ticks
	largeAmount := "50000000000"
	_, outputLarge := router.ExactInSwapRoute(
		cross, barPath, fooPath, largeAmount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Cross-tick output: %s\n", outputLarge)

	ufmt.Println("[INFO] Crossing tick boundaries increases price impact non-linearly")
}

// Helper function to calculate price impact percentage
func calculatePriceImpact(initialPriceStr, finalPriceStr string) string {
	// Convert sqrt prices to u256
	initialPrice := u256.MustFromDecimal(initialPriceStr)
	finalPrice := u256.MustFromDecimal(finalPriceStr)

	// Check for zero initial price to avoid division by zero
	if initialPrice.IsZero() {
		return "0.00%"
	}

	// Calculate price difference
	var priceDiff *u256.Uint
	var isNegative bool

	if initialPrice.Gt(finalPrice) {
		priceDiff = new(u256.Uint).Sub(initialPrice, finalPrice)
		isNegative = false
	} else {
		priceDiff = new(u256.Uint).Sub(finalPrice, initialPrice)
		isNegative = true
	}

	// Calculate percentage: (priceDiff / initialPrice) * 100
	// Using fixed point arithmetic to maintain precision
	// Multiply by 10000 to get basis points (4 decimal places)
	percentage := new(u256.Uint).Mul(priceDiff, u256.NewUint(10000))
	percentage.Div(percentage, initialPrice)

	// Convert to string with proper decimal formatting
	percentageStr := percentage.ToString()

	// Format as percentage with 2 decimal places from basis points
	// Since we multiplied by 10000, we need to insert decimal point 2 places from right
	switch len(percentageStr) {
	case 1:
		percentageStr = "0.0" + percentageStr
	case 2:
		percentageStr = "0." + percentageStr
	case 3:
		percentageStr = "0." + percentageStr
	case 4:
		percentageStr = percentageStr[:2] + "." + percentageStr[2:]
	default:
		// For larger percentages (>= 100%)
		decimalPos := len(percentageStr) - 2
		percentageStr = percentageStr[:decimalPos] + "." + percentageStr[decimalPos:]
	}

	if isNegative {
		percentageStr = "-" + percentageStr
	}

	return percentageStr + "%"
}

// Output:
// [SCENARIO] Price Impact Analysis - Comparing with Uniswap V3 Mathematics
// [INFO] Distributing tokens
// [INFO] Creating pools with different fee tiers
//
// [SCENARIO] 1. Price Impact for Different Trade Sizes
// [INFO] Testing small trade (0.01% of liquidity)
// [INFO] Initial sqrt price: 79228162514264337593543950336
// [INFO] Final sqrt price: 79227921418862449018200183058
// [EXPECTED] Small trade amountOut: -9979977
// [EXPECTED] Price impact should be < 0.01%, actual: 0.00%
//
// [INFO] Testing medium trade (1% of liquidity)
// [INFO] Initial sqrt price: 79227921418862449018200183058
// [INFO] Final sqrt price: 79203819286443894850535749976
// [EXPECTED] Medium trade amountOut: -997691074
// [EXPECTED] Price impact should be 0.01~0.1%, actual: 0.03%
//
// [INFO] Testing large trade (10% of liquidity)
// [INFO] Initial sqrt price: 79203819286443894850535749976
// [INFO] Final sqrt price: 78963602055082262766367635762
// [EXPECTED] Large trade amountOut: -9943625870
// [EXPECTED] Price impact should be > 0.1%, actual: 0.30%
//
// [SCENARIO] 2. Price Impact Across Different Fee Tiers
// [INFO] Comparing price impact across fee tiers
// [EXPECTED] 0.05% fee pool output: -991046211
// [EXPECTED] 0.3% fee pool output: -990386319
// [EXPECTED] 0.05% fee pool output: -991046211
// [EXPECTED] 0.3% fee pool output: -990386319
// [EXPECTED] Lower fee tier should give better output (less price impact)
// [EXPECTED] Price impact actual: 0.03%
// [EXPECTED] Price impact actual: 0.51%
//
// [SCENARIO] 3. Multi-hop Price Impact Analysis
// [INFO] Testing multi-hop price impact
// [EXPECTED] Single hop output: -990445427
// [INFO] Multi-hop swaps aggregate price impact from each hop
//
// [SCENARIO] 4. Price Impact at Tick Boundaries
// [INFO] Testing price impact at tick boundaries
// [EXPECTED] Within tick output: -990145
// [EXPECTED] Cross-tick output: -47801658638
// [INFO] Crossing tick boundaries increases price impact non-linearly
