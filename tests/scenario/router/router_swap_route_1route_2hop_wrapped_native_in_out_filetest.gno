package main

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/demo/wugnot"
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

	wrappedWugnot = "gno.land/r/demo/wugnot"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var (
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	tier1 uint64 = 1
)

var t *testing.T

func main() {
	println("[SCENARIO] #6 Multi-hop Wrapped Native Token Swap Test")
	println("[INFO] Starting scenario: Multi-hop wrapped native token (wugnot) swap tests")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	println("[INFO] Creating bar-baz pool (fee: 500)")
	pl.CreatePool(cross, barPath, bazPath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating baz-qux pool (fee: 500)")
	pl.CreatePool(cross, bazPath, quxPath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating qux-wugnot pool (fee: 500, tick: -10000)")
	pl.CreatePool(cross, wrappedWugnot, quxPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Executing test scenarios")
	println()
	testPositionMintBarBaz(t)
	testPositionMintBazQux(t)
	testPositionMintQuxGnot(t)

	testDrySwapRouteBarGnotExactIn(t)
	testDrySwapRouteBarGnotExactOut(t)
	testDrySwapRouteGnotBarExactIn(t)

	println("[INFO] Scenario completed")
}

func testPositionMintBarBaz(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for bar-baz pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in bar-baz pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, barPath, bazPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")  // bar
	println("[EXPECTED] amount1:", amount1, "expected: 100000") // baz
	println()
}

func testPositionMintBazQux(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for baz-qux pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	baz.Approve(cross, poolAddr, max_approve)
	qux.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in baz-qux pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, bazPath, quxPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 2")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")
	println()
}

func testPositionMintQuxGnot(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for qux-wugnot pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Issuing native tokens to admin")
	// send
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 1000009}})
	testing.SetOriginSend(std.Coins{{"ugnot", 1000009}})

	println("[INFO] Depositing native tokens to get wrapped tokens")
	// Deposit(wrap)
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	println("[INFO] Approving tokens for pool operations")
	qux.Approve(cross, poolAddr, max_approve)
	wugnot.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in qux-wugnot pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, quxPath, wrappedWugnot, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 3")
	println("[EXPECTED] amount0:", amount0, "expected: 100000")
	println("[EXPECTED] amount1:", amount1, "expected: 36790")
	println()
}

func testDrySwapRouteBarGnotExactIn(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route bar to wugnot exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (bar → baz → qux → wugnot)")
	_, dryResult, _ := router.DrySwapRoute(
		barPath,       // inputToken
		wrappedWugnot, // outputToken
		"1000",        // amountSpecified
		"EXACT_IN",    // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/demo/wugnot:500", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 19740")
	println()
}

func testDrySwapRouteBarGnotExactOut(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route bar to wugnot exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (bar → baz → qux → wugnot)")
	dryResult, _, _ := router.DrySwapRoute(
		barPath,       // inputToken
		wrappedWugnot, // outputToken
		"20000",       // amountSpecified
		"EXACT_OUT",   // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/demo/wugnot:500", // strRouteArr
		"100", // quoteArr
		"2000000",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 1014")
	println()
}

func testDrySwapRouteGnotBarExactIn(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route wugnot to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (wugnot → qux → baz → bar)")
	_, dryResult, _ := router.DrySwapRoute(
		wrappedWugnot, // intputToken
		barPath,       // outputToken
		"5000",        // amountSpecified
		"EXACT_IN",    // swapType
		"gno.land/r/demo/wugnot:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 247")
	println()
}

func testDrySwapRouteGnotBarExactOut(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route wugnot to bar exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (wugnot → qux → baz → bar)")
	dryResult, _, _ := router.DrySwapRoute(
		wrappedWugnot, // intputToken
		barPath,       // outputToken
		"100",         // amountSpecified
		"EXACT_OUT",   // swapType
		"gno.land/r/demo/wugnot:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
		"100000",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 2027")
	println()
}

// Output:
// [SCENARIO] #6 Multi-hop Wrapped Native Token Swap Test
// [INFO] Starting scenario: Multi-hop wrapped native token (wugnot) swap tests
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating bar-baz pool (fee: 500)
// [INFO] Creating baz-qux pool (fee: 500)
// [INFO] Creating qux-wugnot pool (fee: 500, tick: -10000)
// [INFO] Executing test scenarios
//
// [SCENARIO] Given: Position minting preparation for bar-baz pool
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] positionId: 1
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Position minting preparation for baz-qux pool
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in baz-qux pool
// [INFO] positionId: 2
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 2 expected: 2
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Position minting preparation for qux-wugnot pool
// [INFO] Issuing native tokens to admin
// [INFO] Depositing native tokens to get wrapped tokens
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in qux-wugnot pool
// [INFO] positionId: 3
// [INFO] amount0: 100000
// [INFO] amount1: 36790
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 3 expected: 3
// [EXPECTED] amount0: 100000 expected: 100000
// [EXPECTED] amount1: 36790 expected: 36790
//
// [SCENARIO] Given: Dry swap route bar to wugnot exact in preparation
// [INFO] Executing dry swap route (bar → baz → qux → wugnot)
// [EXPECTED] dry swap result: 19740 expected: 19740
//
// [SCENARIO] Given: Dry swap route bar to wugnot exact out preparation
// [INFO] Executing dry swap route exact out (bar → baz → qux → wugnot)
// [EXPECTED] dry swap result: 1014 expected: 1014
//
// [SCENARIO] Given: Dry swap route wugnot to bar exact in preparation
// [INFO] Executing dry swap route (wugnot → qux → baz → bar)
// [EXPECTED] dry swap result: 247 expected: 247
//
// [INFO] Scenario completed
