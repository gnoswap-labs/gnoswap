package main

import (
	"chain"
	"testing"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/qux"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

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
	println("[SCENARIO] #5 Wrapped Native Token Swap Test")
	println("[INFO] Starting scenario: Wrapped native token (wugnot) swap tests")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	println("[INFO] Creating qux-wugnot pool (fee: 500, tick: -10000)")
	pl.CreatePool(cross, wrappedWugnot, quxPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Executing test scenarios")
	println()
	testPositionMintQuxGnot(t)
	testDrySwapRouteQuxGnotExactIn(t)
	testDrySwapRouteQuxGnotExactOut(t)

	println("[INFO] Scenario completed")
}

func testPositionMintQuxGnot(t *testing.T) {
	println("[SCENARIO] Given: Position minting preparation for qux-wugnot pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Issuing native tokens to admin")
	// send
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000009}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000009}})

	println("[INFO] Depositing native tokens to get wrapped tokens")
	// Deposit(wrap)
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	println("[INFO] Approving tokens for pool operations")
	qux.Approve(cross, poolAddr, max_approve)
	wugnot.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in qux-wugnot pool")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, quxPath, wrappedWugnot, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 100000")
	println("[EXPECTED] amount1:", amount1, "expected: 36790")
	println()
}

func testDrySwapRouteQuxGnotExactIn(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route qux to wugnot exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (qux → wugnot)")
	_, dryResult, _ := router.DrySwapRoute(
		quxPath,       // inputToken
		wrappedWugnot, // outputToken
		"1000",        // amountSpecified
		"EXACT_IN",    // swapType
		"gno.land/r/onbloc/qux:gno.land/r/gnoland/wugnot:500", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 2707")
	println()
}

func testDrySwapRouteQuxGnotExactOut(t *testing.T) {
	println("[SCENARIO] Given: Dry swap route qux to wugnot exact out preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route exact out (qux → wugnot)")
	dryResult, _, _ := router.DrySwapRoute(
		quxPath,       // inputToken
		wrappedWugnot, // outputToken
		"1000",        // amountSpecified
		"EXACT_OUT",   // swapType
		"gno.land/r/onbloc/qux:gno.land/r/gnoland/wugnot:500", // strRouteArr
		"100", // quoteArr
		"100000",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 370")
	println()
}

// Output:
// [SCENARIO] #5 Wrapped Native Token Swap Test
// [INFO] Starting scenario: Wrapped native token (wugnot) swap tests
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating qux-wugnot pool (fee: 500, tick: -10000)
// [INFO] Executing test scenarios
//
// [SCENARIO] Given: Position minting preparation for qux-wugnot pool
// [INFO] Issuing native tokens to admin
// [INFO] Depositing native tokens to get wrapped tokens
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in qux-wugnot pool
// [INFO] positionId: 1
// [INFO] amount0: 100000
// [INFO] amount1: 36790
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 100000 expected: 100000
// [EXPECTED] amount1: 36790 expected: 36790
//
// [SCENARIO] Given: Dry swap route qux to wugnot exact in preparation
// [INFO] Executing dry swap route (qux → wugnot)
// [EXPECTED] dry swap result: 2707 expected: 2707
//
// [SCENARIO] Given: Dry swap route qux to wugnot exact out preparation
// [INFO] Executing dry swap route exact out (qux → wugnot)
// [EXPECTED] dry swap result: 370 expected: 370
//
// [INFO] Scenario completed
