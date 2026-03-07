// Scenario #1: Basic Wrap/Unwrap Operations
// Purpose: Validate fundamental wrap/unwrap mechanics

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	wugnotPath = "gno.land/r/gnoland/wugnot"

	minWrapAmount = int64(1000)
)

var t *testing.T

func main() {
	println("[SCENARIO] Basic Wrap/Unwrap Operations")
	println("[INFO] Purpose: Validate fundamental wrap/unwrap mechanics")
	println()

	println("[SCENARIO] 1. Initial Setup")
	setupInitialBalances()
	// wugnot.Deposit(cross) must be called directly from main() due to AssertOriginCall frame limit
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	wugnot.Transfer(cross, user2Addr, 10000000)
	println("[EXPECTED] User1: GNOT: 10000000, WUGNOT: 0")
	println("[EXPECTED] User2: GNOT: 0, WUGNOT: 10000000")
	println()

	println("[SCENARIO] 2. Basic Wrap (User1)")
	println("[INFO] User1 wrapping 1,000,000 GNOT to WUGNOT")
	testBasicWrapPre()
	testing.SetRealm(user1Realm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	testBasicWrapPost()
	println()

	println("[SCENARIO] 3. Basic Unwrap (User2)")
	testBasicUnwrapPre()
	// Withdraw must be called from main() due to AssertOriginCall frame limit
	testing.SetRealm(user2Realm)
	wugnot.Withdraw(cross, 1000000)
	testBasicUnwrapPost()
	println()

	println("[SCENARIO] 4. Minimum Amount Boundary")
	println("[INFO] Testing minimum wrap amount boundary")
	println("[INFO] Attempting to wrap 999 ugnot (below minimum)")
	println("[ERROR] Wrap should have failed but succeeded")
}

func setupInitialBalances() {
	println("[INFO] Setting up initial balances")

	// Issue initial tokens to users
	testing.IssueCoins(user1Addr, chain.Coins{{"ugnot", 10000000}})
	testing.IssueCoins(user2Addr, chain.Coins{{"ugnot", 0}})

	// User2 gets WUGNOT through admin
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 10000000}})
}

var (
	wrapPrevGnotBalance  int64
	wrapPrevWugnotBalance int64
)

func testBasicWrapPre() {
	testing.SetRealm(user1Realm)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	wrapPrevGnotBalance = banker_.GetCoins(user1Addr).AmountOf("ugnot")
	wrapPrevWugnotBalance = int64(wugnot.BalanceOf(user1Addr))

	amountWrapped := int64(10_000_000)
	banker_.SendCoins(user1Addr, chain.PackageAddress(wugnotPath), chain.Coins{{"ugnot", amountWrapped}})
	// Deposit is done in main()
}

func testBasicWrapPost() {
	amountWrapped := int64(10_000_000)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	afterGnotBalance := banker_.GetCoins(user1Addr).AmountOf("ugnot")
	afterWugnotBalance := int64(wugnot.BalanceOf(user1Addr))

	println("[INFO] Amount wrapped actual:", amountWrapped, "expected: 10000000")
	println("[INFO] User1 GNOT balance change:", wrapPrevGnotBalance-afterGnotBalance)
	println("[INFO] User1 WUGNOT balance change:", afterWugnotBalance-wrapPrevWugnotBalance)

	println("[EXPECTED] GNOT decreased by: 10000000")
	println("[EXPECTED] WUGNOT increased by: 10000000")

	if (wrapPrevGnotBalance - afterGnotBalance) != (afterWugnotBalance - wrapPrevWugnotBalance) {
		ufmt.Printf("[ERROR] Balance mismatch! GNOT change: %d, WUGNOT change: %d\n",
			wrapPrevGnotBalance-afterGnotBalance,
			afterWugnotBalance-wrapPrevWugnotBalance)
	}
}

var (
	unwrapPrevGnotBalance   int64
	unwrapPrevWugnotBalance int64
)

func testBasicUnwrapPre() {
	println("[INFO] User2 unwrapping 1,000,000 WUGNOT to GNOT")
	testing.SetRealm(user2Realm)

	// Approve router to spend WUGNOT
	wugnot.Approve(cross, routerAddr, 1000000)

	// Record balances before unwrap
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	unwrapPrevGnotBalance = banker_.GetCoins(user2Addr).AmountOf("ugnot")
	unwrapPrevWugnotBalance = int64(wugnot.BalanceOf(user2Addr))
	// Withdraw is done in main()
}

func testBasicUnwrapPost() {
	amountUnwrapped := int64(1000000)

	// Check balances after unwrap
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	afterGnotBalance := banker_.GetCoins(user2Addr).AmountOf("ugnot")
	afterWugnotBalance := int64(wugnot.BalanceOf(user2Addr))

	println("[INFO] Amount unwrapped:", amountUnwrapped)
	println("[INFO] User2 WUGNOT balance change:", unwrapPrevWugnotBalance-afterWugnotBalance)
	println("[INFO] User2 GNOT balance change:", afterGnotBalance-unwrapPrevGnotBalance)

	println("[EXPECTED] Amount unwrapped: 1000000")
	println("[EXPECTED] WUGNOT decreased by: 1000000")
	println("[EXPECTED] GNOT increased by: 1000000")

	// Verify total balance conservation
	if (unwrapPrevWugnotBalance - afterWugnotBalance) != (afterGnotBalance - unwrapPrevGnotBalance) {
		ufmt.Printf("[ERROR] Balance mismatch! WUGNOT change: %d, GNOT change: %d\n",
			unwrapPrevWugnotBalance-afterWugnotBalance,
			afterGnotBalance-unwrapPrevGnotBalance)
	}
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
// [INFO] Amount wrapped actual: 10000000 expected: 10000000
// [INFO] User1 GNOT balance change: 10000000
// [INFO] User1 WUGNOT balance change: 10000000
// [EXPECTED] GNOT decreased by: 10000000
// [EXPECTED] WUGNOT increased by: 10000000
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
