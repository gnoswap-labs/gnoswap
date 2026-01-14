// range order with tick cross hook auto-close

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/p/nt/testutils"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rt "gno.land/r/gnoswap/router"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	maxApprove int64 = 9223372036854775806
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	stakerAddr, _   = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm     = testing.NewUserRealm(stakerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)
)

var (
	fee500      uint32 = 500
	max_timeout int64  = 9999999999
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

var (
	poolSetup        bool = false
	rangeOrderTokenId uint64
	autoClosedPosition bool = false
)

func main() {
	println("[SCENARIO] 1. Setup Pool and Hook")
	setupPoolAndHook()
	println()

	println("[SCENARIO] 2. Alice Creates Range Order")
	testCreateRangeOrder()
	println()

	println("[SCENARIO] 3. Price Crosses Upper Tick")
	testPriceCrossUpperTick()
	println()

	println("[SCENARIO] 4. Verify Auto-Close Triggered")
	testVerifyAutoClose()
	println()

	println("[SCENARIO] 5. Alice Collects Automatically Closed Position")
	testCollectAutoClosedPosition()
	println()
}

func setupPoolAndHook() {
	if !poolSetup {
		println("[INFO] Creating pool with tick cross hook")
		testing.SetRealm(adminRealm)

		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		println("[EXPECTED] Pool created")

		println("[INFO] Setting tick cross hook for auto-close")
		// Pool path is always sorted: bar < foo alphabetically
		poolPath := barPath + ":" + fooPath + ":500"

		// Set hook to auto-close position when upper tick is crossed
		testing.SetRealm(stakerRealm)
		pl.SetTickCrossHook(cross, func(cur realm, path string, tickId int32, zeroForOne bool, timestamp int64) {
			if path == poolPath && tickId == 200 && !zeroForOne {
				println("[HOOK] Upper tick 200 crossed! Auto-closing position")
				autoClosedPosition = true
			}
		})
		println("[EXPECTED] Tick cross hook registered")

		tokenFaucet(fooPath, aliceAddr)
		tokenFaucet(barPath, aliceAddr)
		tokenFaucet(fooPath, bobAddr)
		tokenFaucet(barPath, bobAddr)

		testing.SetRealm(aliceRealm)
		foo.Approve(cross, poolAddr, maxApprove)
		bar.Approve(cross, poolAddr, maxApprove)

		pn.Mint(
			cross,
			fooPath,
			barPath,
			fee500,
			-10000,
			10000,
			"10000000",
			"10000000",
			"0",
			"0",
			max_timeout,
			aliceAddr,
			aliceAddr,
			"",
		)
		println("[EXPECTED] Initial liquidity added")

		poolSetup = true
	}
}

func testCreateRangeOrder() {
	println("[INFO] Alice creates range order with hook")
	testing.SetRealm(aliceRealm)

	fooBalanceBefore := foo.BalanceOf(aliceAddr)

	// Use pool's token order (bar < foo alphabetically)
	rangeOrderTokenId, _, _, _ = pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		100,
		200,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		aliceAddr,
		aliceAddr,
		"",
	)

	fooBalanceAfter := foo.BalanceOf(aliceAddr)

	println("[EXPECTED] Range order created with ID:", rangeOrderTokenId)
	println("[INFO] Foo deposited:", fooBalanceBefore-fooBalanceAfter)
	println("[EXPECTED] Position monitors tick 200 for auto-close")
}

func testPriceCrossUpperTick() {
	println("[INFO] Bob swaps to cross upper tick (200)")
	testing.SetRealm(bobRealm)

	foo.Approve(cross, routerAddr, maxApprove)
	bar.Approve(cross, routerAddr, maxApprove)

	// Swap foo -> bar to move price in positive tick direction
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"2000000",
		fooPath+":"+barPath+":500",
		"0",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price crossed tick 200")
	println("[EXPECTED] Tick cross hook triggered")
}

func testVerifyAutoClose() {
	println("[INFO] Verify auto-close was triggered")

	if autoClosedPosition {
		println("[EXPECTED] Auto-close hook was triggered")
		println("[EXPECTED] Position marked for closure")
	} else {
		println("[INFO] Auto-close not triggered (price may not have crossed)")
	}
}

func testCollectAutoClosedPosition() {
	println("[INFO] Alice collects auto-closed position")
	testing.SetRealm(aliceRealm)

	barBalanceBefore := bar.BalanceOf(aliceAddr)
	fooBalanceBefore := foo.BalanceOf(aliceAddr)

	pn.DecreaseLiquidity(
		cross,
		rangeOrderTokenId,
		"100",
		"0",
		"0",
		max_timeout,
		false,
	)

	pn.CollectFee(cross, rangeOrderTokenId, false)

	barBalanceAfter := bar.BalanceOf(aliceAddr)
	fooBalanceAfter := foo.BalanceOf(aliceAddr)

	println("[EXPECTED] Position liquidity decreased")
	println("[INFO] Bar received:", barBalanceAfter-barBalanceBefore)
	println("[INFO] Foo received:", fooBalanceAfter-fooBalanceBefore)
	println("[EXPECTED] Tokens returned to Alice")
}

func tokenFaucet(tokenPath string, to address) {
	testing.SetRealm(adminRealm)
	defaultAmount := int64(10_000_000_000)

	if tokenPath == fooPath {
		foo.Transfer(cross, to, defaultAmount)
	} else if tokenPath == barPath {
		bar.Transfer(cross, to, defaultAmount)
	}
}

// Output:
// [SCENARIO] 1. Setup Pool and Hook
// [INFO] Creating pool with tick cross hook
// [EXPECTED] Pool created
// [INFO] Setting tick cross hook for auto-close
// [EXPECTED] Tick cross hook registered
// [EXPECTED] Initial liquidity added
//
// [SCENARIO] 2. Alice Creates Range Order
// [INFO] Alice creates range order with hook
// [EXPECTED] Range order created with ID: 2
// [INFO] Foo deposited: 0
// [EXPECTED] Position monitors tick 200 for auto-close
//
// [SCENARIO] 3. Price Crosses Upper Tick
// [INFO] Bob swaps to cross upper tick (200)
// [HOOK] Upper tick 200 crossed! Auto-closing position
// [EXPECTED] Price crossed tick 200
// [EXPECTED] Tick cross hook triggered
//
// [SCENARIO] 4. Verify Auto-Close Triggered
// [INFO] Verify auto-close was triggered
// [EXPECTED] Auto-close hook was triggered
// [EXPECTED] Position marked for closure
//
// [SCENARIO] 5. Alice Collects Automatically Closed Position
// [INFO] Alice collects auto-closed position
// [EXPECTED] Position liquidity decreased
// [INFO] Bar received: 0
// [INFO] Foo received: 502
// [EXPECTED] Tokens returned to Alice
