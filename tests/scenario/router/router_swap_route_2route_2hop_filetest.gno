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

	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"
	gnsPath = "gno.land/r/gnoswap/v1/gns"

	wrappedWugnot = "gno.land/r/demo/wugnot"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806

	fee100 uint32 = 100
)

func main() {
	println("[SCENARIO] #8 2-Route 2-Hop Swap Test")
	println("[INFO] Starting scenario: Multi-route 2-hop swap tests")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating bar-baz pool (fee: 500)")
	pl.CreatePool(cross, barPath, bazPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating baz-qux pool (fee: 500)")
	pl.CreatePool(cross, bazPath, quxPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Executing test scenarios")
	testPositionMint()
	testDrySwapRouteBarQuxExactIn()
	testSwapRouteBarQuxExactIn()
	testSwapRouteBarQuxExactOut()
	testSwapRouteQuxBarExactIn()
	testwapRouteQuxBarExactOut()

	println("[INFO] Scenario completed")
}

func testPositionMint() {
	println("[SCENARIO] Given: Position minting preparation for multiple pools")
	// bar_baz_500 by admin
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)
	qux.Approve(cross, poolAddr, max_approve)

	// Mint
	println("[INFO] Minting position in bar-baz pool")
	pn.Mint(cross, barPath, bazPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")
	println("[INFO] Minting position in baz-qux pool")
	pn.Mint(cross, bazPath, quxPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")
	println()
}

func testDrySwapRouteBarQuxExactIn() {
	println("[SCENARIO] Given: Dry swap route bar to qux exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route with 2 routes (bar → baz → qux)")
	_, dryResult, _ := router.DrySwapRoute(
		barPath,    // inputToken
		quxPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"50,50", // quoteArr
		"1",
	)

	println("[EXPECTED] dry swap result:", dryResult, "expected: 7346")
	println()
}

func testSwapRouteBarQuxExactIn() {
	println("[SCENARIO] Given: Swap route bar to qux exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, poolAddr, 10000)
	qux.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing ExactIn swap with 2 routes (1000 bar → baz → qux)")
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

func testSwapRouteBarQuxExactOut() {
	println("[SCENARIO] Given: Swap route bar to qux exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing ExactOut swap with 2 routes (bar → baz → 1000 qux)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath, // inputToken
		quxPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", // strRouteArr
		"50,50", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 140")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1001")
	println()
}

func testSwapRouteQuxBarExactIn() {
	println("[SCENARIO] Given: Swap route qux to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing ExactIn swap with 2 routes (1000 qux → baz → bar)")
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

func testwapRouteQuxBarExactOut() {
	println("[SCENARIO] Given: Swap route qux to bar exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	qux.Approve(cross, poolAddr, 10000)
	bar.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing ExactOut swap with 2 routes (qux → baz → 1000 bar)")
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
// [SCENARIO] #8 2-Route 2-Hop Swap Test
// [INFO] Starting scenario: Multi-route 2-hop swap tests
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating bar-baz pool (fee: 500)
// [INFO] Creating baz-qux pool (fee: 500)
// [INFO] Executing test scenarios
// [SCENARIO] Given: Position minting preparation for multiple pools
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] Minting position in baz-qux pool
//
// [SCENARIO] Given: Dry swap route bar to qux exact in preparation
// [INFO] Executing dry swap route with 2 routes (bar → baz → qux)
// [EXPECTED] dry swap result: 7346 expected: 7346
//
// [SCENARIO] Given: Swap route bar to qux exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactIn swap with 2 routes (1000 bar → baz → qux)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7318 expected: -7318
//
// [SCENARIO] Given: Swap route bar to qux exact out preparation
// [INFO] Executing ExactOut swap with 2 routes (bar → baz → 1000 qux)
// [EXPECTED] amountIn: 140 expected: 140
// [EXPECTED] amountOut: -1001 expected: -1001
//
// [SCENARIO] Given: Swap route qux to bar exact in preparation
// [INFO] Executing ExactIn swap with 2 routes (1000 qux → baz → bar)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -135 expected: -135
//
// [SCENARIO] Given: Swap route qux to bar exact out preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactOut swap with 2 routes (qux → baz → 1000 bar)
// [EXPECTED] amountIn: 7365 expected: 7365
// [EXPECTED] amountOut: -999 expected: -999
//
// [INFO] Scenario completed
