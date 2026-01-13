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

	aliceRealm = testing.NewUserRealm(alice)
	bobRealm   = testing.NewUserRealm(bob)
)

const (
	maxApprove int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] Orderbook Basic Trade Test")
	println()

	println("[SCENARIO] 1. Setup Tokens")
	setupTokens()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Create Orderbook")
	createOrderbook()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Alice Places Limit Order (Sell FOO)")
	alicePlacesLimitOrder()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Bob Executes Market Order (Buy FOO)")
	bobExecutesMarketOrder()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Alice Claims Order")
	aliceClaimsOrder()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 6. Verify Final Balances")
	verifyBalances()
	println()

	println("[INFO] All scenarios passed!")
}

func setupTokens() {
	// Admin distributes tokens to Alice and Bob
	testing.SetRealm(adminRealm)
	foo.Transfer(cross, alice, 100000000)
	bar.Transfer(cross, bob, 100000000)
	println("[INFO] Transferred 100000000 FOO to Alice")
	println("[INFO] Transferred 100000000 BAR to Bob")
}

func createOrderbook() {
	testing.SetRealm(aliceRealm)
	orderbook.CreateOrderbook(cross, barPath, fooPath) // BAR/FOO orderbook
	println("[EXPECTED] Orderbook created: BAR/FOO")

	info := orderbook.GetOrderbookInfo(barPath, fooPath)
	println("[EXPECTED] Orderbook info:", info)
}

func alicePlacesLimitOrder() {
	testing.SetRealm(aliceRealm)

	println("[INFO] Alice FOO balance before:", foo.BalanceOf(alice))

	// Approve orderbook to spend Alice's FOO tokens
	orderbookAddr := testing.NewCodeRealm(orderbookPath).Address()
	foo.Approve(cross, orderbookAddr, maxApprove)
	println("[INFO] Alice approved FOO tokens")

	// Alice wants to sell 1000 FOO tokens
	// At tick 0 (price = 1.0)
	// Direction: Ask (selling FOO for BAR)
	quantity := u256.NewUint(1000)
	orderId := orderbook.PlaceLimitOrder(
		cross,
		barPath,          // quoteDenom
		fooPath,          // baseDenom
		0,                // tickId (price level)
		orderbook.OrderDirectionAsk, // selling FOO
		quantity,
		0, // no claim bounty
	)

	println("[EXPECTED] Alice placed order ID:", orderId)

	// Check tick state
	tickState := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick state after Alice's order:", tickState)

	// Check Alice's remaining FOO balance
	aliceFooBalance := foo.BalanceOf(alice)
	println("[EXPECTED] Alice FOO balance after order:", aliceFooBalance)
}

func bobExecutesMarketOrder() {
	testing.SetRealm(bobRealm)

	println("[INFO] Bob BAR balance before:", bar.BalanceOf(bob))

	// Approve orderbook to spend Bob's BAR tokens
	orderbookAddr := testing.NewCodeRealm(orderbookPath).Address()
	bar.Approve(cross, orderbookAddr, maxApprove)
	println("[INFO] Bob approved BAR tokens")

	// Bob wants to buy FOO with BAR (market order)
	// He sends 1000 BAR to buy FOO
	inputQuantity := u256.NewUint(1000)
	output := orderbook.ExecuteMarketOrder(
		cross,
		barPath,          // quoteDenom
		fooPath,          // baseDenom
		orderbook.OrderDirectionBid, // buying FOO with BAR
		inputQuantity,
		100, // 1% max slippage
	)

	println("[EXPECTED] Bob market order output:", output.ToString())

	// Check Bob's FOO balance (should have received FOO)
	bobFooBalance := foo.BalanceOf(bob)
	println("[EXPECTED] Bob FOO balance after market order:", bobFooBalance)

	// Check Bob's remaining BAR balance
	bobBarBalance := bar.BalanceOf(bob)
	println("[EXPECTED] Bob BAR balance after market order:", bobBarBalance)

	// Check tick state after execution
	tickState := orderbook.GetTickState(barPath, fooPath, 0)
	println("[EXPECTED] Tick state after Bob's market order:", tickState)
}

func aliceClaimsOrder() {
	testing.SetRealm(aliceRealm)

	// Alice claims her filled order to receive BAR tokens
	output := orderbook.ClaimOrder(
		cross,
		barPath, // quoteDenom
		fooPath, // baseDenom
		0,       // tickId
		0,       // orderId
	)

	println("[EXPECTED] Alice claim output:", output.ToString())

	// Check Alice's BAR balance (should have received BAR)
	aliceBarBalance := bar.BalanceOf(alice)
	println("[EXPECTED] Alice BAR balance after claim:", aliceBarBalance)
}

func verifyBalances() {
	// Final balance verification
	println("[INFO] Final balance verification:")

	aliceFooBalance := foo.BalanceOf(alice)
	aliceBarBalance := bar.BalanceOf(alice)
	println("[EXPECTED] Alice final - FOO:", aliceFooBalance, "BAR:", aliceBarBalance)

	bobFooBalance := foo.BalanceOf(bob)
	bobBarBalance := bar.BalanceOf(bob)
	println("[EXPECTED] Bob final - FOO:", bobFooBalance, "BAR:", bobBarBalance)
}

// Output:
// [SCENARIO] Orderbook Basic Trade Test
//
// [SCENARIO] 1. Setup Tokens
// [INFO] Transferred 100000000 FOO to Alice
// [INFO] Transferred 100000000 BAR to Bob
//
// [SCENARIO] 2. Create Orderbook
// [EXPECTED] Orderbook created: BAR/FOO
// [EXPECTED] Orderbook info: Orderbook(gno.land/r/onbloc/bar/gno.land/r/onbloc/foo): active=true, nextBid=-108000000, nextAsk=182402823, nextOrderId=0
//
// [SCENARIO] 3. Alice Places Limit Order (Sell FOO)
// [INFO] Alice FOO balance before: 100000000
// [INFO] Alice approved FOO tokens
// [EXPECTED] Alice placed order ID: 0
// [EXPECTED] Tick state after Alice's order: Tick[0]: Ask(TAL=1000,CTV=1000,ETAS=0) Bid(TAL=0,CTV=0,ETAS=0)
// [EXPECTED] Alice FOO balance after order: 99999000
//
// [SCENARIO] 4. Bob Executes Market Order (Buy FOO)
// [INFO] Bob BAR balance before: 100000000
// [INFO] Bob approved BAR tokens
// [EXPECTED] Bob market order output: 1000
// [EXPECTED] Bob FOO balance after market order: 1000
// [EXPECTED] Bob BAR balance after market order: 99999000
// [EXPECTED] Tick state after Bob's market order: Tick[0]: Ask(TAL=0,CTV=1000,ETAS=1000) Bid(TAL=0,CTV=0,ETAS=0)
//
// [SCENARIO] 5. Alice Claims Order
// [EXPECTED] Alice claim output: 1000
// [EXPECTED] Alice BAR balance after claim: 1000
//
// [SCENARIO] 6. Verify Final Balances
// [INFO] Final balance verification:
// [EXPECTED] Alice final - FOO: 99999000 BAR: 1000
// [EXPECTED] Bob final - FOO: 1000 BAR: 99999000
//
// [INFO] All scenarios passed!
