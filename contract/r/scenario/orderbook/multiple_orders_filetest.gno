package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/orderbook"

	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
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
	bob   = testutils.TestAddress("bob")
	carol = testutils.TestAddress("carol")

	aliceRealm = testing.NewUserRealm(alice)
	bobRealm   = testing.NewUserRealm(bob)
	carolRealm = testing.NewUserRealm(carol)
)

const (
	maxApprove int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] Multiple Limit Orders Test")
	println()

	println("[SCENARIO] 1. Setup Tokens")
	setupTokens()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Create Orderbook")
	createOrderbook()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Multiple Users Place Limit Orders")
	multipleLimitOrders()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Market Order Partially Fills Multiple Orders")
	partialFill()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Users Claim Filled Orders")
	claimOrders()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 6. Verify Final Balances")
	verifyBalances()
	println()

	println("[INFO] All scenarios passed!")
}

func setupTokens() {
	testing.SetRealm(adminRealm)
	foo.Transfer(cross, alice, 100000000)
	foo.Transfer(cross, bob, 100000000)
	bar.Transfer(cross, carol, 100000000)
	println("[INFO] Transferred 100000000 FOO to Alice")
	println("[INFO] Transferred 100000000 FOO to Bob")
	println("[INFO] Transferred 100000000 BAR to Carol")
}

func createOrderbook() {
	testing.SetRealm(aliceRealm)
	orderbook.CreateOrderbook(cross, barPath, fooPath)
	println("[EXPECTED] Orderbook created: BAR/FOO")
}

func multipleLimitOrders() {
	orderbookAddr := testing.NewCodeRealm(orderbookPath).Address()

	// Alice places order at tick 0 (price = 1.0 BAR per FOO)
	testing.SetRealm(aliceRealm)
	println("[INFO] Alice FOO balance before:", foo.BalanceOf(alice))
	foo.Approve(cross, orderbookAddr, maxApprove)

	aliceOrderId := orderbook.PlaceLimitOrder(
		cross,
		barPath,
		fooPath,
		0, // tick 0
		orderbook.OrderDirectionAsk,
		u256.NewUint(2000), // selling 2000 FOO
		0,
	)
	println("[EXPECTED] Alice placed order ID:", aliceOrderId, "at tick 0 for 2000 FOO")

	// Bob places order at tick 100 (slightly higher price, better for seller)
	testing.SetRealm(bobRealm)
	println("[INFO] Bob FOO balance before:", foo.BalanceOf(bob))
	foo.Approve(cross, orderbookAddr, maxApprove)

	bobOrderId := orderbook.PlaceLimitOrder(
		cross,
		barPath,
		fooPath,
		100, // tick 100 (worse price for buyer)
		orderbook.OrderDirectionAsk,
		u256.NewUint(1500), // selling 1500 FOO
		0,
	)
	println("[EXPECTED] Bob placed order ID:", bobOrderId, "at tick 100 for 1500 FOO")

	// Check orderbook state
	println("[EXPECTED] Alice FOO balance:", foo.BalanceOf(alice))
	println("[EXPECTED] Bob FOO balance:", foo.BalanceOf(bob))

	tickState0 := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick 0 state:", tickState0)

	tickState100 := orderbook.GetTickState(barPath, fooPath, 100)
	println("[EXPECTED] Tick 100 state:", tickState100)
}

func partialFill() {
	testing.SetRealm(carolRealm)

	println("[INFO] Carol BAR balance before:", bar.BalanceOf(carol))

	orderbookAddr := testing.NewCodeRealm(orderbookPath).Address()
	bar.Approve(cross, orderbookAddr, maxApprove)

	// Carol buys 2500 FOO with BAR
	// This should fill:
	// - All of Alice's order at tick 0 (2000 FOO)
	// - Part of Bob's order at tick 100 (500 FOO)
	output := orderbook.ExecuteMarketOrder(
		cross,
		barPath,
		fooPath,
		orderbook.OrderDirectionBid,
		u256.NewUint(3000), // spending 3000 BAR (more than needed for slippage)
		500,                // 5% slippage
	)

	println("[EXPECTED] Carol bought FOO:", output.ToString())
	println("[EXPECTED] Carol FOO balance:", foo.BalanceOf(carol))

	// Check tick states after partial fill
	tickState0 := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick 0 after fill:", tickState0)

	tickState100 := orderbook.GetTickState(barPath, fooPath, 100)
	println("[EXPECTED] Tick 100 after partial fill:", tickState100)
}

func claimOrders() {
	// Alice claims her fully filled order
	testing.SetRealm(aliceRealm)
	aliceOutput := orderbook.ClaimOrder(cross, barPath, fooPath, 0, 0)
	println("[EXPECTED] Alice claimed:", aliceOutput.ToString(), "BAR")
	println("[EXPECTED] Alice BAR balance:", bar.BalanceOf(alice))

	// Bob claims his partially filled order
	testing.SetRealm(bobRealm)
	bobOutput := orderbook.ClaimOrder(cross, barPath, fooPath, 100, 1)
	println("[EXPECTED] Bob claimed:", bobOutput.ToString(), "BAR (partial)")
	println("[EXPECTED] Bob BAR balance:", bar.BalanceOf(bob))
}

func verifyBalances() {
	println("[INFO] Final balance verification:")

	aliceFoo := foo.BalanceOf(alice)
	aliceBar := bar.BalanceOf(alice)
	println("[EXPECTED] Alice - FOO:", aliceFoo, "BAR:", aliceBar)

	bobFoo := foo.BalanceOf(bob)
	bobBar := bar.BalanceOf(bob)
	println("[EXPECTED] Bob - FOO:", bobFoo, "BAR:", bobBar)

	carolFoo := foo.BalanceOf(carol)
	carolBar := bar.BalanceOf(carol)
	println("[EXPECTED] Carol - FOO:", carolFoo, "BAR:", carolBar)
}

// Output:
// [SCENARIO] Multiple Limit Orders Test
//
// [SCENARIO] 1. Setup Tokens
// [INFO] Transferred 100000000 FOO to Alice
// [INFO] Transferred 100000000 FOO to Bob
// [INFO] Transferred 100000000 BAR to Carol
//
// [SCENARIO] 2. Create Orderbook
// [EXPECTED] Orderbook created: BAR/FOO
//
// [SCENARIO] 3. Multiple Users Place Limit Orders
// [INFO] Alice FOO balance before: 100000000
// [EXPECTED] Alice placed order ID: 0 at tick 0 for 2000 FOO
// [INFO] Bob FOO balance before: 100000000
// [EXPECTED] Bob placed order ID: 1 at tick 100 for 1500 FOO
// [EXPECTED] Alice FOO balance: 99998000
// [EXPECTED] Bob FOO balance: 99998500
// [EXPECTED] Tick 0 state: Tick[0]: Ask(TAL=2000,CTV=2000,ETAS=0) Bid(TAL=0,CTV=0,ETAS=0)
// [EXPECTED] Tick 100 state: Tick[100]: Ask(TAL=1500,CTV=1500,ETAS=0) Bid(TAL=0,CTV=0,ETAS=0)
//
// [SCENARIO] 4. Market Order Partially Fills Multiple Orders
// [INFO] Carol BAR balance before: 100000000
// [EXPECTED] Carol bought FOO: 3000
// [EXPECTED] Carol FOO balance: 3000
// [EXPECTED] Tick 0 after fill: Tick[0]: Ask(TAL=0,CTV=2000,ETAS=2000) Bid(TAL=0,CTV=0,ETAS=0)
// [EXPECTED] Tick 100 after partial fill: Tick[100]: Ask(TAL=500,CTV=1500,ETAS=1000) Bid(TAL=0,CTV=0,ETAS=0)
//
// [SCENARIO] 5. Users Claim Filled Orders
// [EXPECTED] Alice claimed: 2000 BAR
// [EXPECTED] Alice BAR balance: 2000
// [EXPECTED] Bob claimed: 1000 BAR (partial)
// [EXPECTED] Bob BAR balance: 1000
//
// [SCENARIO] 6. Verify Final Balances
// [INFO] Final balance verification:
// [EXPECTED] Alice - FOO: 99998000 BAR: 2000
// [EXPECTED] Bob - FOO: 99998500 BAR: 1000
// [EXPECTED] Carol - FOO: 3000 BAR: 99997000
//
// [INFO] All scenarios passed!
