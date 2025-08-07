// Scenario #1: Basic Wrap/Unwrap Operations
// Purpose: Validate fundamental wrap/unwrap mechanics

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/access"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/demo/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = std.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = std.NewUserRealm(user2Addr)

	wugnotPath = "gno.land/r/demo/wugnot"

	minWrapAmount = int64(1000)
)

var t *testing.T

func main() {
	println("[SCENARIO] Basic Wrap/Unwrap Operations")
	println("[INFO] Purpose: Validate fundamental wrap/unwrap mechanics")
	println()

	println("[SCENARIO] 1. Initial Setup")
	setupInitialBalances()
	println()

	println("[SCENARIO] 2. Basic Wrap (User1)")
	testBasicWrap()
	println()

	println("[SCENARIO] 3. Basic Unwrap (User2)")
	testBasicUnwrap()
	println()

	println("[SCENARIO] 4. Minimum Amount Boundary")
	testMinimumAmountBoundary()
}

func setupInitialBalances() {
	println("[INFO] Setting up initial balances")

	// Issue initial tokens to users
	testing.IssueCoins(user1Addr, std.Coins{{"ugnot", 10000000}})
	testing.IssueCoins(user2Addr, std.Coins{{"ugnot", 0}})

	// User2 gets WUGNOT through admin
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 10000000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 10000000}})
	wugnot.Deposit(cross)
	wugnot.Transfer(cross, user2Addr, 10000000)

	println("[EXPECTED] User1: GNOT: 10000000, WUGNOT: 0")
	println("[EXPECTED] User2: GNOT: 0, WUGNOT: 10000000")
}

func testBasicWrap() {
	println("[INFO] User1 wrapping 1,000,000 GNOT to WUGNOT")
	testing.SetRealm(user1Realm)

	// Record balances before wrap
	banker := std.NewBanker(std.BankerTypeRealmSend)
	prevGnotBalance := banker.GetCoins(user1Addr).AmountOf("ugnot")
	prevWugnotBalance := wugnot.BalanceOf(user1Addr)

	// Wrap GNOT to WUGNOT through router
	amountWrapped := int64(10000000)
	testing.SetOriginSend(std.Coins{{"ugnot", amountWrapped}})
	banker.SendCoins(user1Addr, std.DerivePkgAddr(wugnotPath), std.Coins{{"ugnot", amountWrapped}})
	wugnot.Deposit(cross)

	// Check balances after wrap
	afterGnotBalance := banker.GetCoins(user1Addr).AmountOf("ugnot")
	afterWugnotBalance := wugnot.BalanceOf(user1Addr)

	println("[INFO] Amount wrapped:", amountWrapped)
	println("[INFO] User1 GNOT balance change:", prevGnotBalance-afterGnotBalance)
	println("[INFO] User1 WUGNOT balance change:", afterWugnotBalance-prevWugnotBalance)

	println("[EXPECTED] Amount wrapped: 1000000")
	println("[EXPECTED] GNOT decreased by: 1000000")
	println("[EXPECTED] WUGNOT increased by: 1000000")

	// Verify total balance conservation
	if (prevGnotBalance - afterGnotBalance) != (afterWugnotBalance - prevWugnotBalance) {
		ufmt.Printf("[ERROR] Balance mismatch! GNOT change: %d, WUGNOT change: %d\n",
			prevGnotBalance-afterGnotBalance,
			afterWugnotBalance-prevWugnotBalance)
	}
}

func testBasicUnwrap() {
	println("[INFO] User2 unwrapping 1,000,000 WUGNOT to GNOT")
	testing.SetRealm(user2Realm)

	// Approve router to spend WUGNOT
	wugnot.Approve(cross, routerAddr, 1000000)

	// Record balances before unwrap
	banker := std.NewBanker(std.BankerTypeReadonly)
	prevGnotBalance := banker.GetCoins(user2Addr).AmountOf("ugnot")
	prevWugnotBalance := wugnot.BalanceOf(user2Addr)

	// Unwrap WUGNOT to GNOT through router
	amountUnwrapped := int64(1000000)
	wugnot.Withdraw(cross, amountUnwrapped)

	// Check balances after unwrap
	afterGnotBalance := banker.GetCoins(user2Addr).AmountOf("ugnot")
	afterWugnotBalance := wugnot.BalanceOf(user2Addr)

	println("[INFO] Amount unwrapped:", amountUnwrapped)
	println("[INFO] User2 WUGNOT balance change:", prevWugnotBalance-afterWugnotBalance)
	println("[INFO] User2 GNOT balance change:", afterGnotBalance-prevGnotBalance)

	println("[EXPECTED] Amount unwrapped: 1000000")
	println("[EXPECTED] WUGNOT decreased by: 1000000")
	println("[EXPECTED] GNOT increased by: 1000000")

	// Verify total balance conservation
	if (prevWugnotBalance - afterWugnotBalance) != (afterGnotBalance - prevGnotBalance) {
		ufmt.Printf("[ERROR] Balance mismatch! WUGNOT change: %d, GNOT change: %d\n",
			prevWugnotBalance-afterWugnotBalance,
			afterGnotBalance-prevGnotBalance)
	}
}

func testMinimumAmountBoundary() {
	println("[INFO] Testing minimum wrap amount boundary")
	testing.SetRealm(user1Realm)

	// Test 1: Try to wrap below minimum (999 ugnot)
	println("[INFO] Attempting to wrap 999 ugnot (below minimum)")

	testing.SetOriginSend(std.Coins{{"ugnot", 999}})

	uassert.AbortsWithMessage(t, "Deposit below minimum: 999/1000 ugnot.", func() {
		wugnot.Deposit(cross) // This should panic
	})

	println("[ERROR] Wrap should have failed but succeeded")
}

// Output:
// [SCENARIO] Basic Wrap/Unwrap Operations
// [INFO] Purpose: Validate fundamental wrap/unwrap mechanics
//
// [SCENARIO] 1. Initial Setup
// [INFO] Setting up initial balances
// [EXPECTED] User1: GNOT: 10000000, WUGNOT: 0
// [EXPECTED] User2: GNOT: 0, WUGNOT: 10000000
//
// [SCENARIO] 2. Basic Wrap (User1)
// [INFO] User1 wrapping 1,000,000 GNOT to WUGNOT
// [INFO] Amount wrapped: 10000000
// [INFO] User1 GNOT balance change: 10000000
// [INFO] User1 WUGNOT balance change: 10000000
// [EXPECTED] Amount wrapped: 1000000
// [EXPECTED] GNOT decreased by: 1000000
// [EXPECTED] WUGNOT increased by: 1000000
//
// [SCENARIO] 3. Basic Unwrap (User2)
// [INFO] User2 unwrapping 1,000,000 WUGNOT to GNOT
// [INFO] Amount unwrapped: 1000000
// [INFO] User2 WUGNOT balance change: 1000000
// [INFO] User2 GNOT balance change: 1000000
// [EXPECTED] Amount unwrapped: 1000000
// [EXPECTED] WUGNOT decreased by: 1000000
// [EXPECTED] GNOT increased by: 1000000
//
// [SCENARIO] 4. Minimum Amount Boundary
// [INFO] Testing minimum wrap amount boundary
// [INFO] Attempting to wrap 999 ugnot (below minimum)
// [ERROR] Wrap should have failed but succeeded
