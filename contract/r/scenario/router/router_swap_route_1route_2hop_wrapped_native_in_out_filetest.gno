package main

import (
	"chain"
	"testing"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/sol"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"

	wrappedWugnot = "gno.land/r/gnoland/wugnot"

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

	println("[INFO] Creating atom-atone pool (fee: 500)")
	pl.CreatePool(cross, atomPath, atonePath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating atone-sol pool (fee: 500)")
	pl.CreatePool(cross, atonePath, solPath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	println("[INFO] Creating sol-wugnot pool (fee: 500, tick: -10000)")
	pl.CreatePool(cross, wrappedWugnot, solPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Executing test scenarios")
	println()
	testPositionMintAtomAtone(t)
	testPositionMintAtoneSol(t)

	// Deposit must be called from main() due to AssertOriginCall frame limit
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000009}})
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000009}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})

	testPositionMintSolGnot(t)

	testDrySwapRouteAtomGnotExactIn(t)
	testDrySwapRouteAtomGnotExactOut(t)
	testDrySwapRouteGnotAtomExactIn(t)

	println("[INFO] Scenario completed")
}

func testPositionMintAtomAtone(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for atom-atone pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in atom-atone pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, atomPath, atonePath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")  // atom
	println("[EXPECTED] amount1:", amount1, "expected: 100000") // atone
	println()
}

func testPositionMintAtoneSol(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for atone-sol pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	atone.Approve(cross, poolAddr, max_approve)
	sol.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in atone-sol pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, atonePath, solPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 2")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")
	println()
}

func testPositionMintSolGnot(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for sol-wugnot pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Deposit already done in main()")

	println("[INFO] Approving tokens for pool operations")
	sol.Approve(cross, poolAddr, max_approve)
	wugnot.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in sol-wugnot pool")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, solPath, wrappedWugnot, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 3")
	println("[EXPECTED] amount0:", amount0, "expected: 100000")
	println("[EXPECTED] amount1:", amount1, "expected: 36790")
	println()
}

func testDrySwapRouteAtomGnotExactIn(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route atom to wugnot exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (atom → atone → sol → wugnot)")
	_, dryResult, _ := router.DrySwapRoute(
		atomPath,       // inputToken
		wrappedWugnot, // outputToken
		"1000",        // amountSpecified
		"EXACT_IN",    // swapType
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500*POOL*gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoland/wugnot:500", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 19711")
	println()
}

func testDrySwapRouteAtomGnotExactOut(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route atom to wugnot exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (atom → atone → sol → wugnot)")
	dryResult, _, _ := router.DrySwapRoute(
		atomPath,       // inputToken
		wrappedWugnot, // outputToken
		"20000",       // amountSpecified
		"EXACT_OUT",   // swapType
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:500*POOL*gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoland/wugnot:500", // strRouteArr
		"100", // quoteArr
		"2000000",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 1015")
	println()
}

func testDrySwapRouteGnotAtomExactIn(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route wugnot to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (wugnot → sol → atone → atom)")
	_, dryResult, _ := router.DrySwapRoute(
		wrappedWugnot, // intputToken
		atomPath,       // outputToken
		"5000",        // amountSpecified
		"EXACT_IN",    // swapType
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/test_token/sol:500*POOL*gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 247")
	println()
}

func testDrySwapRouteGnotAtomExactOut(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route wugnot to atom exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (wugnot → sol → atone → atom)")
	dryResult, _, _ := router.DrySwapRoute(
		wrappedWugnot, // intputToken
		atomPath,       // outputToken
		"100",         // amountSpecified
		"EXACT_OUT",   // swapType
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/test_token/sol:500*POOL*gno.land/r/gnoswap/test_token/sol:gno.land/r/gnoswap/test_token/atone:500*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
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
// [INFO] Creating atom-atone pool (fee: 500)
// [INFO] Creating atone-sol pool (fee: 500)
// [INFO] Creating sol-wugnot pool (fee: 500, tick: -10000)
// [INFO] Executing test scenarios
//
// [SCENARIO] Given: Position minting preparation for atom-atone pool
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
// [INFO] positionId: 1
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Position minting preparation for atone-sol pool
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atone-sol pool
// [INFO] positionId: 2
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 2 expected: 2
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Position minting preparation for sol-wugnot pool
// [INFO] Deposit already done in main()
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in sol-wugnot pool
// [INFO] positionId: 3
// [INFO] amount0: 100000
// [INFO] amount1: 36790
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 3 expected: 3
// [EXPECTED] amount0: 100000 expected: 100000
// [EXPECTED] amount1: 36790 expected: 36790
//
// [SCENARIO] Given: Dry swap route atom to wugnot exact in preparation
// [INFO] Executing dry swap route (atom → atone → sol → wugnot)
// [EXPECTED] dry swap result: 19711 expected: 19711
//
// [SCENARIO] Given: Dry swap route atom to wugnot exact out preparation
// [INFO] Executing dry swap route exact out (atom → atone → sol → wugnot)
// [EXPECTED] dry swap result: 1015 expected: 1015
//
// [SCENARIO] Given: Dry swap route wugnot to atom exact in preparation
// [INFO] Executing dry swap route (wugnot → sol → atone → atom)
// [EXPECTED] dry swap result: 247 expected: 247
//
// [INFO] Scenario completed
