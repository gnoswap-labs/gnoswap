// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs: none
//
// SCENARIO:
// Verifies the access and halt guards on CancelExternalIncentive:
// 1. Admin creates a pending external incentive
// 2. A stranger cannot cancel it (admin or governance only)
// 3. Safe Mode halts withdrawals, which blocks the cancel just like it blocks
//    EndExternalIncentive - the refund is a withdrawal
// 4. Emergency Mode still allows the cancel, matching the other recovery paths
// 5. The refund reaches the creator and the incentive is removed

package main

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"

	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	strangerAddr  = testutils.TestAddress("stranger")
	strangerRealm = testing.NewUserRealm(strangerAddr)

	refundeeAddr = testutils.TestAddress("refundee")

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000

	incentiveID string
)

func main(cur realm) {
	println("[SCENARIO] Access and halt guards on CancelExternalIncentive")
	println()

	println("[SCENARIO] 1. Initialize, create pool and a pending incentive")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Stranger cannot cancel")
	checkStrangerBlocked(cur)
	println()

	println("[SCENARIO] 3. Safe Mode blocks the cancel")
	checkSafeModeBlocked(cur)
	println()

	println("[SCENARIO] 4. Emergency Mode allows the cancel")
	cancelInEmergencyMode(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)
	testing.SkipHeights(1)

	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTimestamp := ((createTimestamp / 86400) + 1) * 86400
	endTimestamp := startTimestamp + INCENTIVE_DURATION

	incentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func checkStrangerBlocked(cur realm) {
	testing.SetRealm(strangerRealm)

	uassert.AbortsContains(t, cur, "is not admin or governance", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID)
	})
	println("[EXPECTED] stranger rejected: caller is not admin or governance")

	ufmt.Printf("[EXPECTED] incentive untouched: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func checkSafeModeBlocked(cur realm) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] withdraw halted: %t\n", halt.IsHaltedWithdraw())

	uassert.AbortsContains(t, cur, "halted: withdraw", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID)
	})
	println("[EXPECTED] cancel blocked by withdraw halt")
}

func cancelInEmergencyMode(cur realm) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] withdraw halted: %t\n", halt.IsHaltedWithdraw())

	// The refund is returned to the incentive creator (admin created it).
	barBefore := bar.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID)

	ufmt.Printf("[EXPECTED] creator BAR delta: %d\n", bar.BalanceOf(adminAddr)-barBefore)
	ufmt.Printf("[EXPECTED] creator GNS delta: %d\n", gns.BalanceOf(adminAddr)-gnsBefore)
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

// Output:
// [SCENARIO] Access and halt guards on CancelExternalIncentive
//
// [SCENARIO] 1. Initialize, create pool and a pending incentive
// [INFO] pending incentives for pool: 1
//
// [SCENARIO] 2. Stranger cannot cancel
// [EXPECTED] stranger rejected: caller is not admin or governance
// [EXPECTED] incentive untouched: 1
//
// [SCENARIO] 3. Safe Mode blocks the cancel
// [INFO] withdraw halted: true
// [EXPECTED] cancel blocked by withdraw halt
//
// [SCENARIO] 4. Emergency Mode allows the cancel
// [INFO] withdraw halted: false
// [EXPECTED] creator BAR delta: 1000000000
// [EXPECTED] creator GNS delta: 1000000000
// [EXPECTED] remaining incentives for pool: 0
//
