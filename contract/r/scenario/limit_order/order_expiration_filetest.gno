// limit order expiration and cleanup scenario

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
	_ "gno.land/r/gnoswap/limit_order/v1"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	maxApprove int64 = 9223372036854775806
	blockTime  int64 = 5 // 5 seconds per block
)

var t *testing.T

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	limitOrderAddr  address

	aliceAddr   = testutils.TestAddress("alice")
	aliceRealm  = testing.NewUserRealm(aliceAddr)
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

var (
	poolSetup             bool = false
	aliceFooBalanceBefore int64
)

func main() {
	limitOrderAddr = lo.Address()

	println("[SCENARIO] 1. Setup Pool and Liquidity")
	setupPoolAndLiquidity()
	println()

	println("[SCENARIO] 2. Create Orders with Short Expiration (5 min)")
	testCreateShortExpiryOrders()
	println()

	println("[SCENARIO] 3. Skip Time to Expire Orders")
	testSkipTimeToExpire()
	println()

	println("[SCENARIO] 4. Try Execute Expired Order (Should Fail)")
	testExecuteExpiredOrder()
	println()

	println("[SCENARIO] 5. Cleanup Expired Orders")
	testCleanupExpiredOrders()
	println()

	println("[SCENARIO] 6. Verify Refunds")
	testVerifyRefunds()
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
			-10000,
			10000,
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			aliceAddr,
			aliceAddr,
			"",
		)

		println("[EXPECTED] Pool and liquidity setup complete")
		poolSetup = true
	}
}

func testCreateShortExpiryOrders() {
	println("[INFO] Alice creates orders with 5 minute expiration")
	testing.SetRealm(aliceRealm)

	tokenFaucet(fooPath, aliceAddr)
	foo.Approve(cross, limitOrderAddr, maxApprove)

	// Capture balance before creating orders
	aliceFooBalanceBefore = foo.BalanceOf(aliceAddr)
	println("[INFO] Alice foo balance before:", aliceFooBalanceBefore)

	poolPath := fooPath + ":" + barPath + ":500"
	currentTime := time.Now().Unix()
	shortExpiry := currentTime + 300 // 5 minutes (MIN_ORDER_DEADLINE)

	// Create order 1
	orderId1 := lo.CreateOrder(cross,
		poolPath,
		address(fooPath),
		address(barPath),
		1000,
		1000,
		0,
		50,
		shortExpiry,
		aliceAddr,
	)

	// Create order 2
	orderId2 := lo.CreateOrder(cross,
		poolPath,
		address(fooPath),
		address(barPath),
		2000,
		2000,
		0,
		50,
		shortExpiry,
		aliceAddr,
	)

	println("[EXPECTED] Order 1 ID:", orderId1)
	println("[EXPECTED] Order 2 ID:", orderId2)
	println("[EXPECTED] Both orders active with 5 min expiry")
}

func testSkipTimeToExpire() {
	println("[INFO] Skipping 61 blocks (305 seconds) to expire orders")
	// MIN_ORDER_DEADLINE is 300 seconds = 60 blocks
	// Skip 61 blocks to ensure orders are expired
	testing.SkipHeights(61)
	println("[EXPECTED] Orders are now expired")
}

func testExecuteExpiredOrder() {
	println("[INFO] Keeper tries to execute expired order")
	testing.SetRealm(keeperRealm)

	uassert.AbortsContains(t, "order has expired", func() {
		lo.ExecuteOrder(cross, 1, keeperAddr)
	})

	println("[EXPECTED] Execution correctly failed with 'order has expired'")
}

func testCleanupExpiredOrders() {
	println("[INFO] Cleaning up expired orders")
	testing.SetRealm(keeperRealm)

	// Cleanup up to 10 expired orders
	cleaned := lo.CleanupExpiredOrders(cross, 10)

	println("[EXPECTED] Cleaned orders count:", cleaned)
}

func testVerifyRefunds() {
	println("[INFO] Verify Alice received refunds")
	testing.SetRealm(aliceRealm)

	aliceFooBalanceAfter := foo.BalanceOf(aliceAddr)
	println("[INFO] Alice foo balance after:", aliceFooBalanceAfter)

	// Alice deposited 3000 foo (1000 + 2000) and should receive full refund
	// Net change should be 0 (balance before orders == balance after refund)
	netChange := aliceFooBalanceAfter - aliceFooBalanceBefore
	println("[INFO] Net change (should be 0):", netChange)
	println("[EXPECTED] Alice received full refund")
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
// [EXPECTED] Pool and liquidity setup complete
//
// [SCENARIO] 2. Create Orders with Short Expiration (5 min)
// [INFO] Alice creates orders with 5 minute expiration
// [INFO] Alice foo balance before: 9999000000
// [EXPECTED] Order 1 ID: 1
// [EXPECTED] Order 2 ID: 2
// [EXPECTED] Both orders active with 5 min expiry
//
// [SCENARIO] 3. Skip Time to Expire Orders
// [INFO] Skipping 61 blocks (305 seconds) to expire orders
// [EXPECTED] Orders are now expired
//
// [SCENARIO] 4. Try Execute Expired Order (Should Fail)
// [INFO] Keeper tries to execute expired order
// [EXPECTED] Execution correctly failed with 'order has expired'
//
// [SCENARIO] 5. Cleanup Expired Orders
// [INFO] Cleaning up expired orders
// [EXPECTED] Cleaned orders count: 2
//
// [SCENARIO] 6. Verify Refunds
// [INFO] Verify Alice received refunds
// [INFO] Alice foo balance after: 9999000000
// [INFO] Net change (should be 0): 0
// [EXPECTED] Alice received full refund
