// limit order with slippage tolerance scenario

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	lo "gno.land/r/gnoswap/limit_order"
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
	limitOrderAddr  address

	aliceAddr   = testutils.TestAddress("alice")
	aliceRealm  = testing.NewUserRealm(aliceAddr)
	bobAddr     = testutils.TestAddress("bob")
	bobRealm    = testing.NewUserRealm(bobAddr)
	keeperAddr  = testutils.TestAddress("keeper")
	keeperRealm = testing.NewUserRealm(keeperAddr)
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

var t *testing.T

func main() {
	limitOrderAddr = lo.Address()

	println("[SCENARIO] 1. Setup")
	setupPoolAndLiquidity()
	println()

	println("[SCENARIO] 2. Create Order with 1% Slippage Tolerance")
	testCreateOrderWithSlippage()
	println()

	println("[SCENARIO] 3. Move Price Slightly")
	testMovePriceSlightly()
	println()

	println("[SCENARIO] 4. Execute Order (Should Succeed)")
	testExecuteOrderWithSlippage()
	println()

	println("[SCENARIO] 5. Compare: Create Exact Order")
	testCreateExactOrder()
	println()

	println("[SCENARIO] 6. Move Price Unfavorably")
	testMovePriceUnfavorably()
	println()

	println("[SCENARIO] 7. Try Execute Exact Order (Should Fail)")
	testExecuteExactOrder()
	println()
}

func setupPoolAndLiquidity() {
	if !poolSetup {
		testing.SetRealm(adminRealm)

		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

		tokenFaucet(fooPath, aliceAddr)
		tokenFaucet(barPath, aliceAddr)

		testing.SetRealm(aliceRealm)
		foo.Approve(cross, poolAddr, maxApprove)
		bar.Approve(cross, poolAddr, maxApprove)

		pn.Mint(
			cross,
			fooPath,
			barPath,
			fee500,
			-50000,
			50000,
			"10000000",
			"10000000",
			"0",
			"0",
			max_timeout,
			aliceAddr,
			aliceAddr,
			"",
		)

		println("[EXPECTED] Deep liquidity pool ready")
		poolSetup = true
	}
}

func testCreateOrderWithSlippage() {
	println("[INFO] Alice creates order with 1% slippage tolerance")
	testing.SetRealm(aliceRealm)

	tokenFaucet(fooPath, aliceAddr)
	foo.Approve(cross, limitOrderAddr, maxApprove)

	poolPath := fooPath + ":" + barPath + ":500"
	currentTime := time.Now().Unix()
	expiredAt := currentTime + 86400

	orderId := lo.CreateOrder(cross,
		poolPath,
		address(fooPath),
		address(barPath),
		10000, // making 10000 foo
		9500,  // taking 9500 bar (target)
		100,   // 1% slippage tolerance
		50,    // 0.5% keeper fee
		expiredAt,
		aliceAddr,
	)

	println("[EXPECTED] Order ID:", orderId)
	println("[EXPECTED] Minimum acceptable: 9405 bar (9500 - 1%)")
	println("[EXPECTED] Higher success rate due to slippage tolerance")
}

func testMovePriceSlightly() {
	println("[INFO] Bob swaps, price moves slightly against Alice")
	testing.SetRealm(bobRealm)

	tokenFaucet(barPath, bobAddr)
	bar.Approve(cross, routerAddr, maxApprove)

	rt.ExactInSingleSwapRoute(
		cross,
		barPath,
		fooPath,
		"1000",
		barPath+":"+fooPath+":500",
		"1",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price moved slightly (within 1% tolerance)")
}

func testExecuteOrderWithSlippage() {
	println("[INFO] Keeper executes order with slippage tolerance")
	testing.SetRealm(keeperRealm)

	aliceBarBefore := bar.BalanceOf(aliceAddr)

	lo.ExecuteOrder(cross, 1, keeperAddr)

	aliceBarAfter := bar.BalanceOf(aliceAddr)
	received := aliceBarAfter - aliceBarBefore

	println("[EXPECTED] Order executed successfully")
	println("[INFO] Alice received:", received, "bar")
	println("[EXPECTED] Amount >= 9405 bar (minimum with slippage)")
}

func testCreateExactOrder() {
	println("[INFO] Alice creates exact order (0% slippage)")
	testing.SetRealm(aliceRealm)

	foo.Approve(cross, limitOrderAddr, maxApprove)

	poolPath := fooPath + ":" + barPath + ":500"
	currentTime := time.Now().Unix()
	expiredAt := currentTime + 86400

	orderId := lo.CreateOrder(cross,
		poolPath,
		address(fooPath),
		address(barPath),
		10000,
		9500,
		0, // 0% slippage - exact execution required
		50,
		expiredAt,
		aliceAddr,
	)

	println("[EXPECTED] Exact order ID:", orderId)
	println("[EXPECTED] Must receive exactly 9500 bar (or more)")
}

func testMovePriceUnfavorably() {
	println("[INFO] Bob swaps to move price unfavorably for exact order")
	testing.SetRealm(bobRealm)

	tokenFaucet(fooPath, bobAddr)
	foo.Approve(cross, routerAddr, maxApprove)

	// Swap foo -> bar to decrease bar/foo ratio (unfavorable for Alice who wants bar)
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"5000000", // Large swap to significantly move price
		fooPath+":"+barPath+":500",
		"1",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price moved significantly against exact order")
}

func testExecuteExactOrder() {
	println("[INFO] Keeper tries to execute exact order")
	testing.SetRealm(keeperRealm)

	uassert.AbortsContains(t, "limit price not reached", func() {
		lo.ExecuteOrder(cross, 2, keeperAddr)
	})

	println("[EXPECTED] Exact order failed with 'limit price not reached'")
	println("[EXPECTED] Slippage tolerance would have allowed order 1 to succeed here")
}

func tokenFaucet(tokenPath string, to address) {
	testing.SetRealm(adminRealm)
	defaultAmount := int64(5_000_000_000)

	if tokenPath == fooPath {
		foo.Transfer(cross, to, defaultAmount)
	} else if tokenPath == barPath {
		bar.Transfer(cross, to, defaultAmount)
	}
}

// Output:
// [SCENARIO] 1. Setup
// [EXPECTED] Deep liquidity pool ready
//
// [SCENARIO] 2. Create Order with 1% Slippage Tolerance
// [INFO] Alice creates order with 1% slippage tolerance
// [EXPECTED] Order ID: 1
// [EXPECTED] Minimum acceptable: 9405 bar (9500 - 1%)
// [EXPECTED] Higher success rate due to slippage tolerance
//
// [SCENARIO] 3. Move Price Slightly
// [INFO] Bob swaps, price moves slightly against Alice
// [EXPECTED] Price moved slightly (within 1% tolerance)
//
// [SCENARIO] 4. Execute Order (Should Succeed)
// [INFO] Keeper executes order with slippage tolerance
// [EXPECTED] Order executed successfully
// [INFO] Alice received: 9924 bar
// [EXPECTED] Amount >= 9405 bar (minimum with slippage)
//
// [SCENARIO] 5. Compare: Create Exact Order
// [INFO] Alice creates exact order (0% slippage)
// [EXPECTED] Exact order ID: 2
// [EXPECTED] Must receive exactly 9500 bar (or more)
//
// [SCENARIO] 6. Move Price Unfavorably
// [INFO] Bob swaps to move price unfavorably for exact order
// [EXPECTED] Price moved significantly against exact order
//
// [SCENARIO] 7. Try Execute Exact Order (Should Fail)
// [INFO] Keeper tries to execute exact order
// [EXPECTED] Exact order failed with 'limit price not reached'
// [EXPECTED] Slippage tolerance would have allowed order 1 to succeed here
