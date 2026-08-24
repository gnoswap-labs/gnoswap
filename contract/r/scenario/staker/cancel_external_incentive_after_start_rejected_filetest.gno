// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs: none
//
// SCENARIO:
// Verifies the timing boundary between the two teardown paths:
// 1. Admin creates a 90-day external incentive starting at the next midnight
// 2. Cancelling on the last block before the start timestamp is still allowed
//    (done on a second incentive so the first one survives the boundary test)
// 3. Once the start timestamp passes, CancelExternalIncentive aborts - the
//    incentive is live and its record must stay for reward accounting
// 4. Cancelling is still rejected after the end timestamp
// 5. EndExternalIncentive remains the only way to finalize a started incentive

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

	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	refundeeAddr = testutils.TestAddress("refundee")

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000     // 1000 BAR

	liveIncentiveID  string
	spareIncentiveID string
	startTimestamp   int64
	endTimestamp     int64
)

func main(cur realm) {
	println("[SCENARIO] Cancel is only allowed before the start timestamp")
	println()

	println("[SCENARIO] 1. Initialize and create pool")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Admin creates two pending external incentives")
	createPendingIncentives(cur)
	println()

	println("[SCENARIO] 3. Cancel the spare incentive on the last block before start")
	cancelJustBeforeStart(cur)
	println()

	println("[SCENARIO] 4. Cancel is rejected once the incentive has started")
	checkCancelRejectedAfterStart(cur)
	println()

	println("[SCENARIO] 5. Cancel is still rejected after the end timestamp")
	checkCancelRejectedAfterEnd(cur)
	println()

	println("[SCENARIO] 6. EndExternalIncentive finalizes the started incentive")
	endStartedIncentive(cur)
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

	println("[INFO] created pool without internal tier")
}

func createPendingIncentives(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 1) * 86400
	endTimestamp = startTimestamp + INCENTIVE_DURATION

	liveIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	spareIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 2)

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	sr.CreateExternalIncentive(cross(cur), poolPath, quxPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func cancelJustBeforeStart(cur realm) {
	// Land the chain on the last block before the start timestamp.
	skipToTimestamp(startTimestamp - 1)
	ufmt.Printf("[INFO] seconds until start: %d\n", startTimestamp-time.Now().Unix())

	quxBefore := qux.BalanceOf(refundeeAddr)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, spareIncentiveID, refundeeAddr)

	ufmt.Printf("[EXPECTED] refundee QUX delta: %d\n", qux.BalanceOf(refundeeAddr)-quxBefore)
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func checkCancelRejectedAfterStart(cur realm) {
	skipToTimestamp(startTimestamp)
	ufmt.Printf("[INFO] chain time is at the start timestamp: %t\n", time.Now().Unix() >= startTimestamp)

	testing.SetRealm(adminRealm)
	// errCannotCancelIncentive
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-023]", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, liveIncentiveID, refundeeAddr)
	})
	println("[EXPECTED] cancel rejected: incentive already started")
}

func checkCancelRejectedAfterEnd(cur realm) {
	skipToTimestamp(endTimestamp)

	testing.SetRealm(adminRealm)
	// errCannotCancelIncentive
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-023]", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, liveIncentiveID, refundeeAddr)
	})
	println("[EXPECTED] cancel rejected after the end timestamp too")
}

func endStartedIncentive(cur realm) {
	barBefore := bar.BalanceOf(refundeeAddr)
	gnsBefore := gns.BalanceOf(refundeeAddr)

	testing.SetRealm(adminRealm)
	sr.EndExternalIncentive(cross(cur), poolPath, liveIncentiveID, refundeeAddr)

	ufmt.Printf("[EXPECTED] refundee BAR delta: %d\n", bar.BalanceOf(refundeeAddr)-barBefore)
	ufmt.Printf("[EXPECTED] refundee GNS delta: %d\n", gns.BalanceOf(refundeeAddr)-gnsBefore)
	ufmt.Printf("[EXPECTED] ended incentive refunded flag: %t\n", sr.GetIncentiveRefunded(poolPath, liveIncentiveID))
	ufmt.Printf("[EXPECTED] ended incentive still recorded: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

// skipToTimestamp advances the chain to the last block at or before the given
// unix timestamp. Blocks are 5 seconds apart, so flooring keeps the landing
// time from overshooting a boundary the scenario is testing.
func skipToTimestamp(target int64) {
	remaining := target - time.Now().Unix()
	if remaining < 5 {
		return
	}

	testing.SkipHeights(remaining / 5)
}

// Output:
// [SCENARIO] Cancel is only allowed before the start timestamp
//
// [SCENARIO] 1. Initialize and create pool
// [INFO] created pool without internal tier
//
// [SCENARIO] 2. Admin creates two pending external incentives
// [INFO] pending incentives for pool: 2
//
// [SCENARIO] 3. Cancel the spare incentive on the last block before start
// [INFO] seconds until start: 5
// [EXPECTED] refundee QUX delta: 1000000000
// [EXPECTED] remaining incentives for pool: 1
//
// [SCENARIO] 4. Cancel is rejected once the incentive has started
// [INFO] chain time is at the start timestamp: true
// [EXPECTED] cancel rejected: incentive already started
//
// [SCENARIO] 5. Cancel is still rejected after the end timestamp
// [EXPECTED] cancel rejected after the end timestamp too
//
// [SCENARIO] 6. EndExternalIncentive finalizes the started incentive
// [EXPECTED] refundee BAR delta: 1000000000
// [EXPECTED] refundee GNS delta: 1000000000
// [EXPECTED] ended incentive refunded flag: true
// [EXPECTED] ended incentive still recorded: 1
//
