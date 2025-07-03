package main

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
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
	println("[SCENARIO] #7 3-Hop Wrapped Native Token Middle Swap Test")
	println("[INFO] Starting scenario: 3-hop swap with wrapped native token in middle")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating gns-wugnot pool (fee: 100, tick: -10000)")
	pl.CreatePool(cross, wrappedWugnot, gnsPath, fee100, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Creating wugnot-bar pool (fee: 100)")
	pl.CreatePool(cross, wrappedWugnot, barPath, fee100, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Note: 1 gns ≈ 7.29 bar")
	println()

	println("[INFO] Executing test scenarios")
	testPositionMintGnsGnot()
	testPositionMintGnotBar()
	testDrySwapRouteGnsBarExactIn()
	testSwapRouteGnsBarExactIn()

	println("[INFO] Scenario completed")
}

func testPositionMintGnsGnot() {
	println("[SCENARIO] Given: Position minting preparation for gns-wugnot pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Issuing native tokens to admin")
	// send
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 100000}})

	println("[INFO] Depositing native tokens to get wrapped tokens")
	// Deposit(wrap)
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	println("[INFO] Approving tokens for pool operations")
	gns.Approve(cross, poolAddr, max_approve)
	wugnot.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in gns-wugnot pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, gnsPath, wrappedWugnot, fee100, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 100000")
	println("[EXPECTED] amount1:", amount1, "expected: 36790")
	println()
}

func testPositionMintGnotBar() {
	println("[SCENARIO] Given: Position minting preparation for wugnot-bar pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Issuing native tokens to admin")
	// send
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 100000}})

	println("[INFO] Depositing native tokens to get wrapped tokens")
	// Deposit(wrap)
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	println("[INFO] Approving tokens for pool operations")
	gns.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in wugnot-bar pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, wrappedWugnot, barPath, fee100, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 2")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")
	println()
}

func testDrySwapRouteGnsBarExactIn() {
	println("[SCENARIO] Given: Dry swap route gns to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (gns → wugnot → bar)")
	_, dryResult, _ := router.DrySwapRoute(
		gnsPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:100*POOL*gno.land/r/demo/wugnot:gno.land/r/onbloc/bar:100", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 7327")
	println()
}

func testSwapRouteGnsBarExactIn() {
	println("[SCENARIO] Given: Swap route gns to bar exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	gns.Approve(cross, poolAddr, 1000)   // swap input amount
	bar.Approve(cross, routerAddr, 7325) // 0.15% fee

	println("[INFO] Executing ExactIn swap (1000 gns → wugnot → bar)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		gnsPath, // inputToken
		barPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:100*POOL*gno.land/r/demo/wugnot:gno.land/r/onbloc/bar:100", // strRouteArr
		"100", // quoteArr
		"0",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[INFO] amountIn:", amountIn)
	println("[INFO] amountOut:", amountOut)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -7317")
	println()
}

// Output:
// [SCENARIO] #7 3-Hop Wrapped Native Token Middle Swap Test
// [INFO] Starting scenario: 3-hop swap with wrapped native token in middle
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating gns-wugnot pool (fee: 100, tick: -10000)
// [INFO] Creating wugnot-bar pool (fee: 100)
// [INFO] Note: 1 gns ≈ 7.29 bar
//
// [INFO] Executing test scenarios
// [SCENARIO] Given: Position minting preparation for gns-wugnot pool
// [INFO] Issuing native tokens to admin
// [INFO] Depositing native tokens to get wrapped tokens
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in gns-wugnot pool
// [INFO] positionId: 1
// [INFO] amount0: 100000
// [INFO] amount1: 36790
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 100000 expected: 100000
// [EXPECTED] amount1: 36790 expected: 36790
//
// [SCENARIO] Given: Position minting preparation for wugnot-bar pool
// [INFO] Issuing native tokens to admin
// [INFO] Depositing native tokens to get wrapped tokens
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in wugnot-bar pool
// [INFO] positionId: 2
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 2 expected: 2
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Dry swap route gns to bar exact in preparation
// [INFO] Executing dry swap route (gns → wugnot → bar)
// [EXPECTED] dry swap result: 7327 expected: 7327
//
// [SCENARIO] Given: Swap route gns to bar exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactIn swap (1000 gns → wugnot → bar)
// [INFO] amountIn: 1000
// [INFO] amountOut: -7317
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7317 expected: -7317
//
// [INFO] Scenario completed
