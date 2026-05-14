package main

import (
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
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"

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

	println("[INFO] Creating atom-atone pool (fee: 500)")
	pl.CreatePool(cross, atomPath, atonePath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating atone-sol pool (fee: 500)")
	pl.CreatePool(cross, atonePath, solPath, uint32(500), "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, maxApprove)
	atone.Approve(cross, poolAddr, maxApprove)
	sol.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Minting positions in atom-atone pool")
	pn.Mint(cross, atomPath, atonePath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")
	println("[INFO] Minting positions in atone-sol pool")
	pn.Mint(cross, atonePath, solPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] Executing test scenarios")
	println()
	testDrySwapRouteAtomSolExactIn()
	testSwapRouteAtomSolExactIn()
	testDrySwapRouteAtomSolExactOut()
	testSwapRouteAtomSolExactOut()
	TestDrySwapRouteSolAtomExactIn()
	TestSwapRouteSolAtomExactIn()
	TestDrySwapRouteSolAtomExactOut()
	TestSwapRouteSolAtomExactOut()

	testing.SetRealm(adminRealm)

	println("[INFO] Scenario completed")
}

func testDrySwapRouteAtomSolExactIn() {
	println("[SCENARIO] Given: Dry swap route atom to sol exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (atom → atone → sol)")
	_, dryResult, _ := router.DrySwapRoute(
		atomPath,    // inputToken
		solPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"100", // quoteArr
		"100",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 7326")
	println()
}

func testSwapRouteAtomSolExactIn() {
	println("[SCENARIO] Given: Swap route atom to sol exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing swap route (atom → atone → sol)")
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

func testDrySwapRouteAtomSolExactOut() {
	println("[SCENARIO] Given: Dry swap route atom to sol exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (atom → atone → sol)")
	dryResult, _, _ := router.DrySwapRoute(
		atomPath,     // inputToken
		solPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500,gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"50,50", // quoteArr
		"10000",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 140")
	println()
}

func testSwapRouteAtomSolExactOut() {
	println("[SCENARIO] Given: Swap route atom to sol exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, 99999)

	println("[INFO] Executing swap route exact out (atom → atone → sol)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath, // inputToken
		solPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500,gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500", // strRouteArr
		"60,40", // quoteArr
		"99999", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 141")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1001")
	println()
}

func TestDrySwapRouteSolAtomExactIn() {
	println("[SCENARIO] Given: Dry swap route sol to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (sol → atone → atom)")
	_, dryResult, _ := router.DrySwapRoute(
		solPath,    // inputToken
		atomPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500,gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"30,70", // quoteArr
		"1",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 135")
	println()
}

func TestSwapRouteSolAtomExactIn() {
	println("[SCENARIO] Given: Swap route sol to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	sol.Approve(cross, routerAddr, 10000)

	println("[INFO] Executing swap route (sol → atone → atom)")
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

func TestDrySwapRouteSolAtomExactOut() {
	println("[SCENARIO] Given: Dry swap route sol to atom exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (sol → atone → atom)")
	dryResult, _, _ := router.DrySwapRoute(
		solPath,     // inputToken
		atomPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500,gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"30,70", // quoteArr
		"100000",
	)

	println("[EXPECTED] dryResult:", dryResult, "expected: 7359")
	println()
}

func TestSwapRouteSolAtomExactOut() {
	println("[SCENARIO] Given: Swap route sol to atom exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	sol.Approve(cross, routerAddr, 99999)

	println("[INFO] Executing swap route exact out (sol → atone → atom)")
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

	println("[EXPECTED] amountIn:", amountIn, "expected: 7365")
	println("[EXPECTED] amountOut:", amountOut, "expected: -999")
	println()
}

// Output:
// [SCENARIO] #2 Route 2 Hop Test
// [INFO] Starting scenario: Multi-hop routing with 2 routes and 2 hops
// [INFO] Setting up pools and positions
// [INFO] Creating atom-atone pool (fee: 500)
// [INFO] Creating atone-sol pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting positions in atom-atone pool
// [INFO] Minting positions in atone-sol pool
// [INFO] Executing test scenarios
//
// [SCENARIO] Given: Dry swap route atom to sol exact in preparation
// [INFO] Executing dry swap route (atom → atone → sol)
// [EXPECTED] dryResult: 7326 expected: 7326
//
// [SCENARIO] Given: Swap route atom to sol exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route (atom → atone → sol)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7318 expected: -7318
//
// [SCENARIO] Given: Dry swap route atom to sol exact out preparation
// [INFO] Executing dry swap route exact out (atom → atone → sol)
// [EXPECTED] dryResult: 140 expected: 140
//
// [SCENARIO] Given: Swap route atom to sol exact out preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route exact out (atom → atone → sol)
// [EXPECTED] amountIn: 141 expected: 141
// [EXPECTED] amountOut: -1001 expected: -1001
//
// [SCENARIO] Given: Dry swap route sol to atom exact in preparation
// [INFO] Executing dry swap route (sol → atone → atom)
// [EXPECTED] dryResult: 135 expected: 135
//
// [SCENARIO] Given: Swap route sol to atom exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route (sol → atone → atom)
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -135 expected: -135
//
// [SCENARIO] Given: Dry swap route sol to atom exact out preparation
// [INFO] Executing dry swap route exact out (sol → atone → atom)
// [EXPECTED] dryResult: 7359 expected: 7359
//
// [SCENARIO] Given: Swap route sol to atom exact out preparation
// [INFO] Approving tokens for swap
// [INFO] Executing swap route exact out (sol → atone → atom)
// [EXPECTED] amountIn: 7373 expected: 7365
// [EXPECTED] amountOut: -1000 expected: -999
//
// [INFO] Scenario completed
