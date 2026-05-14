package main

import (
	"chain"
	"testing"
	"time"

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
	println("[SCENARIO] #7 3-Hop Wrapped Native Token Middle Swap Test")
	println("[INFO] Starting scenario: 3-hop swap with wrapped native token in middle")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating gns-wugnot pool (fee: 100, tick: -10000)")
	pl.CreatePool(cross, wrappedWugnot, gnsPath, fee100, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Creating wugnot-atom pool (fee: 100)")
	pl.CreatePool(cross, wrappedWugnot, atomPath, fee100, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Note: 1 gns ≈ 7.29 atom")
	println()

	println("[INFO] Executing test scenarios")

	// Deposit must be called from main() due to AssertOriginCall frame limit
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 200000}})
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 200000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})

	testPositionMintGnsGnot()
	testPositionMintGnotAtom()
	testDrySwapRouteGnsAtomExactIn()
	testSwapRouteGnsAtomExactIn()

	println("[INFO] Scenario completed")
}

func testPositionMintGnsGnot() {
	println("[SCENARIO] Given: Position minting preparation for gns-wugnot pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Deposit already done in main()")

	println("[INFO] Approving tokens for pool operations")
	gns.Approve(cross, poolAddr, max_approve)
	wugnot.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in gns-wugnot pool")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, gnsPath, wrappedWugnot, fee100, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 100000")
	println("[EXPECTED] amount1:", amount1, "expected: 36790")
	println()
}

func testPositionMintGnotAtom() {
	println("[SCENARIO] Given: Position minting preparation for wugnot-atom pool")
	testing.SetRealm(adminRealm)

	println("[INFO] Deposit already done in main()")

	println("[INFO] Approving tokens for pool operations")
	gns.Approve(cross, poolAddr, max_approve)
	atom.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in wugnot-atom pool")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, wrappedWugnot, atomPath, fee100, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 2")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")
	println()
}

func testDrySwapRouteGnsAtomExactIn() {
	println("[SCENARIO] Given: Dry swap route gns to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Executing dry swap route (gns → wugnot → atom)")
	_, dryResult, _ := router.DrySwapRoute(
		gnsPath,    // inputToken
		atomPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:100*POOL*gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/test_token/atom:100", // strRouteArr
		"100", // quoteArr
		"1",
	)
	println("[EXPECTED] dry swap result:", dryResult, "expected: 7317")
	println()
}

func testSwapRouteGnsAtomExactIn() {
	println("[SCENARIO] Given: Swap route gns to atom exact in preparation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	gns.Approve(cross, routerAddr, 1000) // swap input amount

	println("[INFO] Executing ExactIn swap (1000 gns → wugnot → atom)")
	testing.SetOriginSend(chain.Coins{})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		gnsPath, // inputToken
		atomPath, // outputToken
		"1000",  // amountSpecified
		"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:100*POOL*gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/test_token/atom:100", // strRouteArr
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
// [INFO] Creating wugnot-atom pool (fee: 100)
// [INFO] Note: 1 gns ≈ 7.29 atom
//
// [INFO] Executing test scenarios
// [SCENARIO] Given: Position minting preparation for gns-wugnot pool
// [INFO] Deposit already done in main()
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
// [SCENARIO] Given: Position minting preparation for wugnot-atom pool
// [INFO] Deposit already done in main()
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in wugnot-atom pool
// [INFO] positionId: 2
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 2 expected: 2
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
//
// [SCENARIO] Given: Dry swap route gns to atom exact in preparation
// [INFO] Executing dry swap route (gns → wugnot → atom)
// [EXPECTED] dry swap result: 7317 expected: 7317
//
// [SCENARIO] Given: Swap route gns to atom exact in preparation
// [INFO] Approving tokens for swap
// [INFO] Executing ExactIn swap (1000 gns → wugnot → atom)
// [INFO] amountIn: 1000
// [INFO] amountOut: -7317
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -7317 expected: -7317
//
// [INFO] Scenario completed
