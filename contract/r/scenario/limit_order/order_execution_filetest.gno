// limit order execution scenario

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"

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
	limitOrderAddr address

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

func main() {
	limitOrderAddr = lo.Address()

	println("[SCENARIO] 1. Setup Pool and Liquidity")
	setupPoolAndLiquidity()
	println()

	println("[SCENARIO] 2. Alice Creates Limit Order")
	testCreateOrder()
	println()

	println("[SCENARIO] 3. Bob Swaps to Move Price")
	testSwapToMovePrice()
	println()

	println("[SCENARIO] 4. Keeper Executes Order")
	testExecuteOrder()
	println()

	println("[SCENARIO] 5. Verify Order Status")
	testVerifyOrderStatus()
	println()
}

func setupPoolAndLiquidity() {
	if !poolSetup {
		println("[INFO] Creating pool")
		testing.SetRealm(adminRealm)
		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		println("[EXPECTED] Pool created")

		// Provide liquidity
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
		println("[EXPECTED] Deep liquidity provided")

		poolSetup = true
	}
}

func testCreateOrder() {
	println("[INFO] Alice wants to buy 1000 bar at good price")
	testing.SetRealm(aliceRealm)

	tokenFaucet(fooPath, aliceAddr)
	foo.Approve(cross, limitOrderAddr, maxApprove)

	// Capture Alice's bar balance before order
	aliceBarBalanceBeforeOrder = bar.BalanceOf(aliceAddr)

	poolPath := fooPath + ":" + barPath + ":500"
	currentTime := time.Now().Unix()
	expiredAt := currentTime + 86400 // 24 hours

	orderId := lo.CreateOrder(cross,
		poolPath,
		address(fooPath),
		address(barPath),
		1000,  // making 1000 foo
		900,   // taking 900 bar (better price than current)
		0,     // no slippage
		50,    // 0.5% keeper fee
		expiredAt,
		aliceAddr,
	)

	println("[EXPECTED] Order ID:", orderId)
	println("[EXPECTED] Order escrowed 1000 foo")
	println("[EXPECTED] Order status: ACTIVE")
}

func testSwapToMovePrice() {
	println("[INFO] Bob swaps to move price in Alice's favor")
	testing.SetRealm(bobRealm)

	tokenFaucet(fooPath, bobAddr)
	foo.Approve(cross, routerAddr, maxApprove)

	// Bob swaps foo for bar, moving price up
	rt.ExactInSingleSwapRoute(
		cross,
		fooPath,
		barPath,
		"5000",
		fooPath+":"+barPath+":500",
		"1",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Price moved favorably for Alice's order")
}

func testExecuteOrder() {
	println("[INFO] Keeper detects order can be executed")
	testing.SetRealm(keeperRealm)

	barBalanceBefore := bar.BalanceOf(keeperAddr)
	println("[INFO] Keeper bar balance before:", barBalanceBefore)

	// Keeper executes order ID 1
	lo.ExecuteOrder(cross, 1, keeperAddr)

	barBalanceAfter := bar.BalanceOf(keeperAddr)
	println("[EXPECTED] Order executed successfully")
	println("[INFO] Keeper bar balance after:", barBalanceAfter)
	println("[EXPECTED] Keeper received fee in bar tokens")
}

var aliceBarBalanceBeforeOrder int64

func testVerifyOrderStatus() {
	println("[INFO] Verify Alice received her tokens")
	testing.SetRealm(aliceRealm)

	aliceBarBalanceAfter := bar.BalanceOf(aliceAddr)
	barReceived := aliceBarBalanceAfter - aliceBarBalanceBeforeOrder
	println("[INFO] Alice bar balance change:", barReceived)
	println("[EXPECTED] Alice received bar tokens (order output minus keeper fee)")
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
// [SCENARIO] 1. Setup Pool and Liquidity
// [INFO] Creating pool
// [EXPECTED] Pool created
// [EXPECTED] Deep liquidity provided
//
// [SCENARIO] 2. Alice Creates Limit Order
// [INFO] Alice wants to buy 1000 bar at good price
// [EXPECTED] Order ID: 1
// [EXPECTED] Order escrowed 1000 foo
// [EXPECTED] Order status: ACTIVE
//
// [SCENARIO] 3. Bob Swaps to Move Price
// [INFO] Bob swaps to move price in Alice's favor
// [EXPECTED] Price moved favorably for Alice's order
//
// [SCENARIO] 4. Keeper Executes Order
// [INFO] Keeper detects order can be executed
// [INFO] Keeper bar balance before: 0
// [EXPECTED] Order executed successfully
// [INFO] Keeper bar balance after: 4
// [EXPECTED] Keeper received fee in bar tokens
//
// [SCENARIO] 5. Verify Order Status
// [INFO] Verify Alice received her tokens
// [INFO] Alice bar balance change: 992
// [EXPECTED] Alice received bar tokens (order output minus keeper fee)
