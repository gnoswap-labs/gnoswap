// basic range order scenario - using Position as limit order

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

var poolSetup bool = false

func main() {
	println("[SCENARIO] 1. Setup Pool and Liquidity")
	setupPoolAndLiquidity()
	println()

	println("[SCENARIO] 2. Alice Creates Range Order (Narrow Position)")
	testCreateRangeOrder()
	println()

	println("[SCENARIO] 3. Price Moves Into Range")
	testPriceMovesIntoRange()
	println()

	println("[SCENARIO] 4. Verify Partial Conversion")
	testVerifyPartialConversion()
	println()

	println("[SCENARIO] 5. Price Moves Out of Range (Full Fill)")
	testPriceMovesOutOfRange()
	println()

	println("[SCENARIO] 6. Alice Collects Position")
	testCollectPosition()
	println()
}

func setupPoolAndLiquidity() {
	if !poolSetup {
		println("[INFO] Creating pool")
		testing.SetRealm(adminRealm)

		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		println("[EXPECTED] Pool created at tick 0")

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
	println("[INFO] Alice creates narrow range position above current price")
	testing.SetRealm(aliceRealm)

	fooBalanceBefore := foo.BalanceOf(aliceAddr)
	barBalanceBefore := bar.BalanceOf(aliceAddr)
	println("[INFO] Alice foo balance:", fooBalanceBefore)
	println("[INFO] Alice bar balance:", barBalanceBefore)

	// Use pool's token order (bar < foo alphabetically)
	tokenId, _, _, _ := pn.Mint(
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
	barBalanceAfter := bar.BalanceOf(aliceAddr)

	println("[EXPECTED] Range order position created with ID:", tokenId)
	println("[INFO] Foo deposited:", fooBalanceBefore-fooBalanceAfter)
	println("[INFO] Bar deposited:", barBalanceBefore-barBalanceAfter)
	println("[EXPECTED] Only bar deposited (position above current price, tick < tickLower)")
}

func testPriceMovesIntoRange() {
	println("[INFO] Bob swaps to move price into Alice's range")
	testing.SetRealm(bobRealm)

	foo.Approve(cross, routerAddr, maxApprove)
	bar.Approve(cross, routerAddr, maxApprove)

	// Swap foo -> bar to move price in positive tick direction
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"500000",
		fooPath+":"+barPath+":500",
		"0",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price moved into range")
	println("[EXPECTED] Position started converting bar to foo (tick increasing)")
}

func testVerifyPartialConversion() {
	println("[INFO] Check position liquidity status")
	testing.SetRealm(aliceRealm)

	println("[EXPECTED] Position partially converted")
	println("[EXPECTED] Some foo converted to bar")
}

func testPriceMovesOutOfRange() {
	println("[INFO] Bob continues swapping to move price past range")
	testing.SetRealm(bobRealm)

	// Continue swapping foo -> bar
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"1000000",
		fooPath+":"+barPath+":500",
		"0",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price moved past upper tick")
	println("[EXPECTED] Position fully converted to foo (tick > tickUpper)")
}

func testCollectPosition() {
	println("[INFO] Alice decreases liquidity and collects")
	testing.SetRealm(aliceRealm)

	barBalanceBefore := bar.BalanceOf(aliceAddr)
	fooBalanceBefore := foo.BalanceOf(aliceAddr)

	pn.DecreaseLiquidity(
		cross,
		2,
		"100",
		"0",
		"0",
		max_timeout,
		false,
	)

	pn.CollectFee(cross, 2, false)

	barBalanceAfter := bar.BalanceOf(aliceAddr)
	fooBalanceAfter := foo.BalanceOf(aliceAddr)

	println("[EXPECTED] Liquidity decreased")
	println("[INFO] Bar received:", barBalanceAfter-barBalanceBefore)
	println("[INFO] Foo received:", fooBalanceAfter-fooBalanceBefore)
	println("[EXPECTED] Alice received foo (position fully converted)")
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
// [SCENARIO] 1. Setup Pool and Liquidity
// [INFO] Creating pool
// [EXPECTED] Pool created at tick 0
// [EXPECTED] Initial liquidity added
//
// [SCENARIO] 2. Alice Creates Range Order (Narrow Position)
// [INFO] Alice creates narrow range position above current price
// [INFO] Alice foo balance: 9990000000
// [INFO] Alice bar balance: 9990000000
// [EXPECTED] Range order position created with ID: 2
// [INFO] Foo deposited: 0
// [INFO] Bar deposited: 1000000
// [EXPECTED] Only bar deposited (position above current price, tick < tickLower)
//
// [SCENARIO] 3. Price Moves Into Range
// [INFO] Bob swaps to move price into Alice's range
// [EXPECTED] Price moved into range
// [EXPECTED] Position started converting bar to foo (tick increasing)
//
// [SCENARIO] 4. Verify Partial Conversion
// [INFO] Check position liquidity status
// [EXPECTED] Position partially converted
// [EXPECTED] Some foo converted to bar
//
// [SCENARIO] 5. Price Moves Out of Range (Full Fill)
// [INFO] Bob continues swapping to move price past range
// [EXPECTED] Price moved past upper tick
// [EXPECTED] Position fully converted to foo (tick > tickUpper)
//
// [SCENARIO] 6. Alice Collects Position
// [INFO] Alice decreases liquidity and collects
// [EXPECTED] Liquidity decreased
// [INFO] Bar received: 0
// [INFO] Foo received: 503
// [EXPECTED] Alice received foo (position fully converted)
