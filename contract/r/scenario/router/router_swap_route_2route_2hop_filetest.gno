package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/sol"

	_ "gno.land/r/gnoswap/router/v1"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"
	gnsPath = "gno.land/r/gnoswap/gns"

	wrappedWugnot = "gno.land/r/gnoland/wugnot"

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

	println("[INFO] Creating atom-atone pool (fee: 500)")
	pl.CreatePool(cross, atomPath, atonePath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating atone-sol pool (fee: 500)")
	pl.CreatePool(cross, atonePath, solPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Executing test scenarios")
	testPositionMint()
	testDrySwapRouteAtomSolExactIn()
	testSwapRouteAtomSolExactIn()
	testSwapRouteAtomSolExactOut()
	testSwapRouteSolAtomExactIn()
	testwapRouteSolAtomExactOut()

	println("[INFO] Scenario completed")
}

func testPositionMint() {
	println("[SCENARIO] Given: Position minting preparation for multiple pools")
	// atom_baz_500 by admin
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)
	sol.Approve(cross, poolAddr, max_approve)

	// Mint
	println("[INFO] Minting position in atom-atone pool")
	pn.Mint(cross, atomPath, atonePath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")
	println("[INFO] Minting position in atone-sol pool")
	pn.Mint(cross, atonePath, solPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")
	println()
}

func testDrySwapRouteAtomSolExactIn() {
	println("[SCENARIO] Given: Dry swap route atom to sol exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route with 2 routes (atom → atone → sol)")
	_, dryResult, _ := router.DrySwapRoute(
		atomPath,    // inputToken
		solPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500,gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"50,50", // quoteArr
		"1",
	)

	println("[EXPECTED] dry swap result:", dryResult, "expected: 7335")
	println()
}

func testSwapRouteAtomSolExactIn() {
	println("[SCENARIO] Given: Swap route atom to sol exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, chain.PackageAddress("gno.land/r/gnoswap/router"), 10000)
	sol.Approve(cross, chain.PackageAddress("gno.land/r/gnoswap/router"), 10000)

	println("[INFO] Executing ExactIn swap with 2 routes (1000 atom → atone → sol)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		atomPath, // inputToken
		solPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500,gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"50,50", // quoteArr
		"1",     // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -7318")
	println()
}

func testSwapRouteAtomSolExactOut() {
	println("[SCENARIO] Given: Swap route atom to sol exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing ExactOut swap with 2 routes (atom → atone → 1000 sol)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath, // inputToken
		solPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500,gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"50,50", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 140")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1001")
	println()
}

func testSwapRouteSolAtomExactIn() {
	println("[SCENARIO] Given: Swap route sol to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing ExactIn swap with 2 routes (1000 sol → atone → atom)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		solPath, // inputToken
		atomPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500,gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"30,70", // quoteArr
		"1",     // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -135")
	println()
}

func testwapRouteSolAtomExactOut() {
	println("[SCENARIO] Given: Swap route sol to atom exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	sol.Approve(cross, routerAddr, 10000)
	atom.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing ExactOut swap with 2 routes (sol → atone → 1000 atom)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		solPath, // inputToken
		atomPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500,gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"30,70", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 7373")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1000")
	println()
}

// Output:
// [SCENARIO] #8 2-Route 2-Hop Swap Test
// [INFO] Starting scenario: Multi-route 2-hop swap tests
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating atom-atone pool (fee: 500)
// [INFO] Creating atone-sol pool (fee: 500)
// [INFO] Executing test scenarios
// [SCENARIO] Given: Position minting preparation for multiple pools
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
// [INFO] Minting position in atone-sol pool
//
// [SCENARIO] Given: Dry swap route atom to sol exact in preparation
// [INFO] Executing dry swap route with 2 routes (atom → atone → sol)
// [EXPECTED] dry swap result: 7335 expected: 7335
//
// [SCENARIO] Given: Swap route atom to sol exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactIn swap with 2 routes (1000 atom → atone → sol)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7318 expected: -7318
//
// [SCENARIO] Given: Swap route atom to sol exact out preparation
// [INFO] Executing ExactOut swap with 2 routes (atom → atone → 1000 sol)
// [EXPECTED] amountIn: 140 expected: 140
// [EXPECTED] amountOut: -1001 expected: -1001
//
// [SCENARIO] Given: Swap route sol to atom exact in preparation
// [INFO] Executing ExactIn swap with 2 routes (1000 sol → atone → atom)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -135 expected: -135
//
// [SCENARIO] Given: Swap route sol to atom exact out preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactOut swap with 2 routes (sol → atone → 1000 atom)
// [EXPECTED] amountIn: 7373 expected: 7373
// [EXPECTED] amountOut: -1000 expected: -1000
//
// [INFO] Scenario completed
