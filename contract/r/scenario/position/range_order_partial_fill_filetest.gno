// range order with partial fill and auto-close

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
	poolSetup         bool = false
	rangeOrderTokenId uint64
	partialFillDetected bool = false
)

func main() {
	println("[SCENARIO] 1. Setup Pool with Partial Fill Detection")
	setupPoolWithHook()
	println()

	println("[SCENARIO] 2. Alice Creates Range Order")
	testCreateRangeOrder()
	println()

	println("[SCENARIO] 3. Price Enters Range (Partial Fill Starts)")
	testPriceEntersRange()
	println()

	println("[SCENARIO] 4. Price Exits Range Before Full Fill")
	testPriceExitsRangeEarly()
	println()

	println("[SCENARIO] 5. Detect Partial Fill and Auto-Close")
	testDetectPartialFill()
	println()

	println("[SCENARIO] 6. Alice Collects Partially Filled Position")
	testCollectPartialPosition()
	println()
}

func setupPoolWithHook() {
	if !poolSetup {
		println("[INFO] Creating pool with partial fill detection")
		testing.SetRealm(adminRealm)

		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		println("[EXPECTED] Pool created")

		println("[INFO] Setting tick cross hook for partial fill detection")
		// Pool path is always sorted: bar < foo alphabetically
		poolPath := barPath + ":" + fooPath + ":500"

		testing.SetRealm(stakerRealm)
		pl.SetTickCrossHook(cross, func(cur realm, path string, tickId int32, zeroForOne bool, timestamp int64) {
			if path == poolPath {
				if tickId == 100 && zeroForOne {
					println("[HOOK] Exited range at lower tick - partial fill detected")
					partialFillDetected = true
				}
			}
		})
		println("[EXPECTED] Partial fill detection hook registered")

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
	println("[INFO] Alice creates range order (tick 100-200)")
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
	println("[EXPECTED] Waiting for price to enter range")
}

func testPriceEntersRange() {
	println("[INFO] Bob swaps to move price into range")
	testing.SetRealm(bobRealm)

	foo.Approve(cross, routerAddr, maxApprove)
	bar.Approve(cross, routerAddr, maxApprove)

	// Swap foo -> bar to move price into range (positive tick direction)
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"300000",
		fooPath+":"+barPath+":500",
		"0",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price entered range")
	println("[EXPECTED] Partial conversion started")
}

func testPriceExitsRangeEarly() {
	println("[INFO] Bob swaps back to exit range before full fill")
	testing.SetRealm(bobRealm)

	// Swap bar -> foo to exit range (negative tick direction)
	rt.ExactInSingleSwapRoute(
		cross,
		barPath,
		fooPath,
		"400000",
		barPath+":"+fooPath+":500",
		"0",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price exited range at lower tick")
	println("[EXPECTED] Position only partially filled")
}

func testDetectPartialFill() {
	println("[INFO] Verify partial fill detection")

	if partialFillDetected {
		println("[EXPECTED] Partial fill detected by hook")
		println("[EXPECTED] Position ready for collection")
	} else {
		println("[INFO] Hook may not have triggered (check tick crossing)")
	}
}

func testCollectPartialPosition() {
	println("[INFO] Alice collects partially filled position")
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

	println("[EXPECTED] Partial position collected")
	println("[INFO] Bar received:", barBalanceAfter-barBalanceBefore)
	println("[INFO] Foo received:", fooBalanceAfter-fooBalanceBefore)
	println("[EXPECTED] Alice received mix of foo and bar (partial fill)")
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
// [SCENARIO] 1. Setup Pool with Partial Fill Detection
// [INFO] Creating pool with partial fill detection
// [EXPECTED] Pool created
// [INFO] Setting tick cross hook for partial fill detection
// [EXPECTED] Partial fill detection hook registered
// [EXPECTED] Initial liquidity added
//
// [SCENARIO] 2. Alice Creates Range Order
// [INFO] Alice creates range order (tick 100-200)
// [EXPECTED] Range order created with ID: 2
// [INFO] Foo deposited: 0
// [EXPECTED] Waiting for price to enter range
//
// [SCENARIO] 3. Price Enters Range (Partial Fill Starts)
// [INFO] Bob swaps to move price into range
// [EXPECTED] Price entered range
// [EXPECTED] Partial conversion started
//
// [SCENARIO] 4. Price Exits Range Before Full Fill
// [INFO] Bob swaps back to exit range before full fill
// [HOOK] Exited range at lower tick - partial fill detected
// [EXPECTED] Price exited range at lower tick
// [EXPECTED] Position only partially filled
//
// [SCENARIO] 5. Detect Partial Fill and Auto-Close
// [INFO] Verify partial fill detection
// [EXPECTED] Partial fill detected by hook
// [EXPECTED] Position ready for collection
//
// [SCENARIO] 6. Alice Collects Partially Filled Position
// [INFO] Alice collects partially filled position
// [EXPECTED] Partial position collected
// [INFO] Bar received: 76
// [INFO] Foo received: 77
// [EXPECTED] Alice received mix of foo and bar (partial fill)
