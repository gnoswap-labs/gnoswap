package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/orderbook"

	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/foo"

	u256 "gno.land/p/gnoswap/uint256"
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	orderbookPath = "gno.land/r/gnoswap/orderbook"
)

// Test users
var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	alice = testutils.TestAddress("alice")

	aliceRealm = testing.NewUserRealm(alice)
)

const (
	maxApprove int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] Cancel Order Test")
	println()

	println("[SCENARIO] 1. Setup Tokens")
	setupTokens()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Create Orderbook")
	createOrderbook()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Alice Places Limit Order")
	aliceOrder := alicePlacesOrder()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Check Balance After Order")
	checkBalanceAfterOrder()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Alice Cancels Order")
	aliceCancelsOrder(aliceOrder)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 6. Verify Refund")
	verifyRefund()
	println()

	println("[INFO] All scenarios passed!")
}

func setupTokens() {
	testing.SetRealm(adminRealm)
	foo.Transfer(cross, alice, 100000000)
	println("[INFO] Transferred 100000000 FOO to Alice")
}

func createOrderbook() {
	testing.SetRealm(aliceRealm)
	orderbook.CreateOrderbook(cross, barPath, fooPath)
	println("[EXPECTED] Orderbook created: BAR/FOO")
}

func alicePlacesOrder() uint64 {
	testing.SetRealm(aliceRealm)

	println("[INFO] Alice FOO balance before:", foo.BalanceOf(alice))

	orderbookAddr := testing.NewCodeRealm(orderbookPath).Address()
	foo.Approve(cross, orderbookAddr, maxApprove)

	// Alice places order to sell 5000 FOO
	orderId := orderbook.PlaceLimitOrder(
		cross,
		barPath,
		fooPath,
		0, // tick 0
		orderbook.OrderDirectionAsk,
		u256.NewUint(5000),
		0,
	)

	println("[EXPECTED] Alice placed order ID:", orderId, "for 5000 FOO")

	// Check order info
	orderInfo := orderbook.GetOrder(barPath, fooPath, 0, orderId)
	println("[EXPECTED] Order info:", orderInfo)

	return orderId
}

func checkBalanceAfterOrder() {
	aliceFoo := foo.BalanceOf(alice)
	println("[EXPECTED] Alice FOO balance after order:", aliceFoo)

	tickState := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick state:", tickState)
}

func aliceCancelsOrder(orderId uint64) {
	testing.SetRealm(aliceRealm)

	// Cancel the order
	orderbook.CancelLimitOrder(cross, barPath, fooPath, 0, orderId)
	println("[EXPECTED] Alice cancelled order ID:", orderId)

	// Check tick state after cancel
	tickState := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick state after cancel:", tickState)
}

func verifyRefund() {
	aliceFoo := foo.BalanceOf(alice)
	println("[EXPECTED] Alice FOO balance after refund:", aliceFoo)

	// Verify the order was deleted
	// Attempting to get the order should show it doesn't exist
	orderInfo := orderbook.GetOrder(barPath, fooPath, 0, 0)
	println("[EXPECTED] Order info after cancel:", orderInfo)
}

// Output:
// [SCENARIO] Cancel Order Test
//
// [SCENARIO] 1. Setup Tokens
// [INFO] Transferred 100000000 FOO to Alice
//
// [SCENARIO] 2. Create Orderbook
// [EXPECTED] Orderbook created: BAR/FOO
//
// [SCENARIO] 3. Alice Places Limit Order
// [INFO] Alice FOO balance before: 100000000
// [EXPECTED] Alice placed order ID: 0 for 5000 FOO
// [EXPECTED] Order info: Order[0:0]: owner=g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh, dir=ask, qty=5000, etas=0, bounty=0bps, placed=2009-02-13 23:31:40
//
// [SCENARIO] 4. Check Balance After Order
// [EXPECTED] Alice FOO balance after order: 99995000
// [EXPECTED] Tick state: Tick[0]: Ask(TAL=5000,CTV=5000,ETAS=0) Bid(TAL=0,CTV=0,ETAS=0)
//
// [SCENARIO] 5. Alice Cancels Order
// [EXPECTED] Alice cancelled order ID: 0
// [EXPECTED] Tick state after cancel: Tick[0]: Ask(TAL=0,CTV=5000,ETAS=0) Bid(TAL=0,CTV=0,ETAS=0)
//
// [SCENARIO] 6. Verify Refund
// [EXPECTED] Alice FOO balance after refund: 100000000
// [EXPECTED] Order info after cancel: Order not found
//
// [INFO] All scenarios passed!
