// PKGPATH: gno.land/r/gnoswap/v1/main

// Scenario: Halting withdrawals requires governance
//
// This test verifies that a single admin key cannot freeze user funds:
//   - Admin cannot set SAFE_MODE or COMPLETE (both halt withdrawals)
//   - Admin cannot halt the withdraw operation directly
//   - Admin can still set EMERGENCY / NONE and halt non-withdraw operations
//   - Governance can set SAFE_MODE, which blocks withdrawals
//   - Admin can unhalt withdrawals set by governance
//
// Test cases:
//   1. Admin SAFE_MODE is rejected, withdrawals stay open
//   2. Admin COMPLETE is rejected, withdrawals stay open
//   3. Admin SetOperationStatus(withdraw, true) is rejected
//   4. Admin EMERGENCY works, withdrawals stay open, admin NONE restores
//   5. Admin can halt the router individually
//   6. Governance SAFE_MODE works, DecreaseLiquidity blocked
//   7. Admin cannot re-halt withdraw but can unhalt it, DecreaseLiquidity works

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	"gno.land/r/gnoswap/scenarioutils"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac/v1"
	_ "gno.land/r/gnoswap/rbac/v1"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/emission"
	_ "gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const INT64_MAX int64 = 9223372036854775807

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)
	govRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance")

	poolAddr = access.MustGetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee     = uint32(3000)

	positionId uint64
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] Halting withdrawals requires governance")
	println()

	ufmt.Println("[STEP 1] Initialize pool and position")
	initPoolAndPosition(cur)
	println()

	ufmt.Println("[STEP 2] Admin SAFE_MODE is rejected")
	testAdminSafeModeRejected(cur)
	println()

	ufmt.Println("[STEP 3] Admin COMPLETE is rejected")
	testAdminCompleteRejected(cur)
	println()

	ufmt.Println("[STEP 4] Admin cannot halt withdraw operation directly")
	testAdminWithdrawOpRejected(cur)
	println()

	ufmt.Println("[STEP 5] Admin EMERGENCY and NONE still work")
	testAdminEmergencyAndNoneWork(cur)
	println()

	ufmt.Println("[STEP 6] Admin can halt non-withdraw operations individually")
	testAdminHaltsRouter(cur)
	println()

	ufmt.Println("[STEP 7] Governance SAFE_MODE blocks withdrawals")
	testGovernanceSafeModeBlocksWithdraw(cur)
	println()

	ufmt.Println("[STEP 8] Admin cannot re-halt but can unhalt withdraw")
	testAdminUnhaltsWithdraw(cur)
	println()
}

func initPoolAndPosition(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)

	bar.Transfer(cross(cur), aliceAddr, 100000000)
	foo.Transfer(cross(cur), aliceAddr, 100000000)

	pool.SetPoolCreationFee(cross(cur), 0)
	pool.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	testing.SetOriginSend(chain.Coins{})
	id, liquidity, _, _ := position.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)
	positionId = id

	ufmt.Printf("[INFO] Position minted with ID: %d, Liquidity: %s\n", positionId, liquidity)
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testAdminSafeModeRejected(cur realm) {
	testing.SetRealm(adminRealm)

	uassert.AbortsContains(t, cur, "is not governance", func() {
		halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)
	})

	ufmt.Println("[SUCCESS] Admin SAFE_MODE rejected with 'is not governance'")
	ufmt.Printf("[INFO] Withdraw halted: %t (should be false)\n", halt.IsHaltedWithdraw())
}

func testAdminCompleteRejected(cur realm) {
	testing.SetRealm(adminRealm)

	uassert.AbortsContains(t, cur, "is not governance", func() {
		halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)
	})

	ufmt.Println("[SUCCESS] Admin COMPLETE rejected with 'is not governance'")
	ufmt.Printf("[INFO] Withdraw halted: %t (should be false)\n", halt.IsHaltedWithdraw())
	ufmt.Printf("[INFO] Governance halted: %t (should be false)\n", halt.IsHaltedGovernance())
}

func testAdminWithdrawOpRejected(cur realm) {
	testing.SetRealm(adminRealm)

	uassert.AbortsContains(t, cur, "is not governance", func() {
		halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, true)
	})

	ufmt.Println("[SUCCESS] Admin SetOperationStatus(withdraw, true) rejected with 'is not governance'")
	ufmt.Printf("[INFO] Withdraw halted: %t (should be false)\n", halt.IsHaltedWithdraw())
}

func testAdminEmergencyAndNoneWork(cur realm) {
	testing.SetRealm(adminRealm)

	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	ufmt.Println("[SUCCESS] Admin set EMERGENCY")
	ufmt.Printf("[INFO] Pool halted: %t (should be true)\n", halt.IsHaltedPool())
	ufmt.Printf("[INFO] Withdraw halted: %t (should be false)\n", halt.IsHaltedWithdraw())

	// Withdraw path still open: position is halted in EMERGENCY, so use NONE to prove withdraw works
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	ufmt.Println("[SUCCESS] Admin set NONE")
	ufmt.Printf("[INFO] Pool halted: %t (should be false)\n", halt.IsHaltedPool())
}

func testAdminHaltsRouter(cur realm) {
	testing.SetRealm(adminRealm)

	halt.SetOperationStatus(cross(cur), halt.OpTypeRouter, true)
	ufmt.Printf("[SUCCESS] Admin halted router: %t (should be true)\n", halt.IsHaltedRouter())

	halt.SetOperationStatus(cross(cur), halt.OpTypeRouter, false)
	ufmt.Printf("[SUCCESS] Admin resumed router: %t (should be false)\n", halt.IsHaltedRouter())
}

func testGovernanceSafeModeBlocksWithdraw(cur realm) {
	testing.SetRealm(govRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)

	ufmt.Println("[SUCCESS] Governance set SAFE_MODE")
	ufmt.Printf("[INFO] Withdraw halted: %t (should be true)\n", halt.IsHaltedWithdraw())
	ufmt.Printf("[INFO] Position halted: %t (should be false)\n", halt.IsHaltedPosition())

	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(t, cur, "halted: withdraw", func() {
		position.DecreaseLiquidity(
			cross(cur),
			positionId,
			"1000000",
			"0",
			"0",
			time.Now().Unix()+3600,
		)
	})

	ufmt.Println("[SUCCESS] DecreaseLiquidity correctly blocked with 'halted: withdraw'")
}

func testAdminUnhaltsWithdraw(cur realm) {
	testing.SetRealm(adminRealm)

	uassert.AbortsContains(t, cur, "is not governance", func() {
		halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, true)
	})
	ufmt.Println("[SUCCESS] Admin re-halting withdraw rejected with 'is not governance'")

	halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, false)
	ufmt.Printf("[SUCCESS] Admin unhalted withdraw: %t (should be false)\n", halt.IsHaltedWithdraw())

	testing.SetRealm(aliceRealm)
	_, liquidity, _, _, _, _, _ := position.DecreaseLiquidity(
		cross(cur),
		positionId,
		"1000000",
		"0",
		"0",
		time.Now().Unix()+3600,
	)

	ufmt.Printf("[SUCCESS] DecreaseLiquidity works after admin unhalt! Liquidity removed: %s\n", liquidity)
}

// Output:
// [SCENARIO] Halting withdrawals requires governance
//
// [STEP 1] Initialize pool and position
// [INFO] Position minted with ID: 1, Liquidity: 213383746
// [INFO] Withdraw halted: false
//
// [STEP 2] Admin SAFE_MODE is rejected
// [SUCCESS] Admin SAFE_MODE rejected with 'is not governance'
// [INFO] Withdraw halted: false (should be false)
//
// [STEP 3] Admin COMPLETE is rejected
// [SUCCESS] Admin COMPLETE rejected with 'is not governance'
// [INFO] Withdraw halted: false (should be false)
// [INFO] Governance halted: false (should be false)
//
// [STEP 4] Admin cannot halt withdraw operation directly
// [SUCCESS] Admin SetOperationStatus(withdraw, true) rejected with 'is not governance'
// [INFO] Withdraw halted: false (should be false)
//
// [STEP 5] Admin EMERGENCY and NONE still work
// [SUCCESS] Admin set EMERGENCY
// [INFO] Pool halted: true (should be true)
// [INFO] Withdraw halted: false (should be false)
// [SUCCESS] Admin set NONE
// [INFO] Pool halted: false (should be false)
//
// [STEP 6] Admin can halt non-withdraw operations individually
// [SUCCESS] Admin halted router: true (should be true)
// [SUCCESS] Admin resumed router: false (should be false)
//
// [STEP 7] Governance SAFE_MODE blocks withdrawals
// [SUCCESS] Governance set SAFE_MODE
// [INFO] Withdraw halted: true (should be true)
// [INFO] Position halted: false (should be false)
// [SUCCESS] DecreaseLiquidity correctly blocked with 'halted: withdraw'
//
// [STEP 8] Admin cannot re-halt but can unhalt withdraw
// [SUCCESS] Admin re-halting withdraw rejected with 'is not governance'
// [SUCCESS] Admin unhalted withdraw: false (should be false)
// [SUCCESS] DecreaseLiquidity works after admin unhalt! Liquidity removed: 1000000
