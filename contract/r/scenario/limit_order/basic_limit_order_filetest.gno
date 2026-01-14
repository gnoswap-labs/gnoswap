// basic limit order scenario

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
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	limitOrderAddr address

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
	limitOrderAddr = lo.Address()

	println("[SCENARIO] 1. Setup Pool and Liquidity")
	setupPoolAndLiquidity()
	println()

	println("[SCENARIO] 2. Create Limit Order")
	testCreateLimitOrder()
	println()

	println("[SCENARIO] 3. Cancel Limit Order")
	testCancelLimitOrder()
	println()
}

func setupPoolAndLiquidity() {
	if !poolSetup {
		println("[INFO] Setting up pool and initial liquidity")
		testing.SetRealm(adminRealm)

		// Create pool
		pl.SetPoolCreationFee(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		println("[EXPECTED] Pool created: foo:bar:500")

		// Mint tokens to alice
		tokenFaucet(fooPath, aliceAddr)
		tokenFaucet(barPath, aliceAddr)

		// Alice creates initial position
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
		println("[EXPECTED] Initial liquidity position created")

		poolSetup = true
	}
}

func testCreateLimitOrder() {
	println("[INFO] Alice creates a limit order: buy 1000 bar with 1000 foo")
	testing.SetRealm(aliceRealm)

	// Ensure alice has tokens
	tokenFaucet(fooPath, aliceAddr)

	// Approve limit order contract to spend tokens
	foo.Approve(cross, limitOrderAddr, maxApprove)

	// Create limit order
	poolPath := fooPath + ":" + barPath + ":500"
	currentTime := time.Now().Unix()
	expiredAt := currentTime + 3600 // 1 hour from now

	orderId := lo.CreateOrder(
		cross,
		poolPath,
		address(fooPath), // inputMint
		address(barPath), // outputMint
		1000,             // makingAmount
		1000,             // takingAmount
		0,                // slippageBps (exact)
		50,               // feeBps (0.5%)
		expiredAt,
		aliceAddr,        // caller
	)

	println("[EXPECTED] Order created with ID:", orderId)
	println("[EXPECTED] Order status: ACTIVE")
}

func testCancelLimitOrder() {
	println("[INFO] Alice cancels her limit order")
	testing.SetRealm(aliceRealm)

	// Get alice's foo balance before cancel
	fooBalanceBefore := foo.BalanceOf(aliceAddr)
	println("[INFO] Alice foo balance before cancel:", fooBalanceBefore)

	// Cancel order ID 1
	lo.CancelOrder(cross, 1, aliceAddr)

	println("[EXPECTED] Order cancelled successfully")
	println("[EXPECTED] Tokens refunded to Alice")

	// Check balance after cancel
	fooBalanceAfter := foo.BalanceOf(aliceAddr)
	println("[INFO] Alice foo balance after cancel:", fooBalanceAfter)
	println("[EXPECTED] Balance increased by 1000")
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
// [INFO] Setting up pool and initial liquidity
// [EXPECTED] Pool created: foo:bar:500
// [EXPECTED] Initial liquidity position created
//
// [SCENARIO] 2. Create Limit Order
// [INFO] Alice creates a limit order: buy 1000 bar with 1000 foo
// [EXPECTED] Order created with ID: 1
// [EXPECTED] Order status: ACTIVE
//
// [SCENARIO] 3. Cancel Limit Order
// [INFO] Alice cancels her limit order
// [INFO] Alice foo balance before cancel: 9998999000
// [EXPECTED] Order cancelled successfully
// [EXPECTED] Tokens refunded to Alice
// [INFO] Alice foo balance after cancel: 9999000000
// [EXPECTED] Balance increased by 1000

