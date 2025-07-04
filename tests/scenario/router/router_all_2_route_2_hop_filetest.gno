package main

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	max_timeout int64 = 9999999999
	maxApprove  int64 = 9223372036854775806
)

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] #2 Route 2 Hop Test")
	println("[INFO] Starting scenario: Multi-hop routing with 2 routes and 2 hops")

	testing.SetRealm(adminRealm)

	println("[INFO] Setting up pools and positions")
	// create pool
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating bar-baz pool (fee: 500)")
	pl.CreatePool(cross, barPath, bazPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating baz-qux pool (fee: 500)")
	pl.CreatePool(cross, bazPath, quxPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)
	qux.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Minting positions in bar-baz pool")
	pn.Mint(cross, barPath, bazPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")
	println("[INFO] Minting positions in baz-qux pool")
	pn.Mint(cross, bazPath, quxPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] Executing test scenarios")
	println()
	testDrySwapRouteBarQuxExactIn()
	testSwapRouteBarQuxExactIn()
	testDrySwapRouteBarQuxExactOut()
	testSwapRouteBarQuxExactOut()
	TestDrySwapRouteQuxBarExactIn()
	TestSwapRouteQuxBarExactIn()
	TestDrySwapRouteQuxBarExactOut()
	TestSwapRouteQuxBarExactOut()

	println("[INFO] Scenario completed")
}

func testDrySwapRouteBarQuxExactIn() {
	println("[SCENARIO] Given: Dry swap route bar to qux exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (bar → baz → qux)")
	_, dryResult, _ := router.DrySwapRoute(
		barPath,    // inputToken
		quxPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"100", // quoteArr
		"100",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 7337")
	println()
}

func testSwapRouteBarQuxExactIn() {
	println("[SCENARIO] Given: Swap route bar to qux exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, poolAddr, 10000)
	qux.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing swap route (bar → baz → qux)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath, // inputToken
		quxPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"50,50", // quoteArr
		"1",     // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -7318")
	println()
}

func testDrySwapRouteBarQuxExactOut() {
	println("[SCENARIO] Given: Dry swap route bar to qux exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (bar → baz → qux)")
	dryResult, _, _ := router.DrySwapRoute(
		barPath,     // inputToken
		quxPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"50,50", // quoteArr
		"10000",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 140")
	println()
}

func testSwapRouteBarQuxExactOut() {
	println("[SCENARIO] Given: Swap route bar to qux exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing swap route exact out (bar → baz → qux)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath, // inputToken
		quxPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"60,40", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 141")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1001")
	println()
}

func TestDrySwapRouteQuxBarExactIn() {
	println("[SCENARIO] Given: Dry swap route qux to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (qux → baz → bar)")
	_, dryResult, _ := router.DrySwapRoute(
		quxPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500,gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"30,70", // quoteArr
		"1",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 135")
	println()
}

func TestSwapRouteQuxBarExactIn() {
	println("[SCENARIO] Given: Swap route qux to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing swap route (qux → baz → bar)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		quxPath, // inputToken
		barPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500,gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"30,70", // quoteArr
		"1",     // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -135")
	println()
}

func TestDrySwapRouteQuxBarExactOut() {
	println("[SCENARIO] Given: Dry swap route qux to bar exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (qux → baz → bar)")
	dryResult, _, _ := router.DrySwapRoute(
		quxPath,     // inputToken
		barPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500,gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"30,70", // quoteArr
		"100000",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 7351")
	println()
}

func TestSwapRouteQuxBarExactOut() {
	println("[SCENARIO] Given: Swap route qux to bar exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	qux.Approve(cross, poolAddr, 10000)
	bar.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing swap route exact out (qux → baz → bar)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		quxPath, // inputToken
		barPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500,gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"30,70", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 7365")
	println("[EXPECTED] amountOut:", amountOut, "expected: -999")
	println()
}

// Output:
// [SCENARIO] #2 Route 2 Hop Test
// [INFO] Starting scenario: Multi-hop routing with 2 routes and 2 hops
// [INFO] Setting up pools and positions
// [INFO] Creating bar-baz pool (fee: 500)
// [INFO] Creating baz-qux pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting positions in bar-baz pool
// [INFO] Minting positions in baz-qux pool
// [INFO] Executing test scenarios
//
// [SCENARIO] Given: Dry swap route bar to qux exact in preparation
// [INFO] Executing dry swap route (bar → baz → qux)
// [EXPECTED] dryResult: 7337 expected: 7337
//
// [SCENARIO] Given: Swap route bar to qux exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route (bar → baz → qux)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7318 expected: -7318
//
// [SCENARIO] Given: Dry swap route bar to qux exact out preparation
// [INFO] Executing dry swap route exact out (bar → baz → qux)
// [EXPECTED] dryResult: 140 expected: 140
//
// [SCENARIO] Given: Swap route bar to qux exact out preparation
// [INFO] Executing swap route exact out (bar → baz → qux)
// [EXPECTED] amountIn: 141 expected: 141
// [EXPECTED] amountOut: -1001 expected: -1001
//
// [SCENARIO] Given: Dry swap route qux to bar exact in preparation
// [INFO] Executing dry swap route (qux → baz → bar)
// [EXPECTED] dryResult: 135 expected: 135
//
// [SCENARIO] Given: Swap route qux to bar exact in preparation
// [INFO] Executing swap route (qux → baz → bar)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -135 expected: -135
//
// [SCENARIO] Given: Dry swap route qux to bar exact out preparation
// [INFO] Executing dry swap route exact out (qux → baz → bar)
// [EXPECTED] dryResult: 7351 expected: 7351
//
// [SCENARIO] Given: Swap route qux to bar exact out preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route exact out (qux → baz → bar)
// [EXPECTED] amountIn: 7365 expected: 7365
// [EXPECTED] amountOut: -999 expected: -999
//
// [INFO] Scenario completed
