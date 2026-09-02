// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs: none
//
// SCENARIO:
// CreateExternalIncentive is open to any account, so an incentive creator is not
// necessarily admin. CancelExternalIncentive is therefore callable by the
// creator as well as admin and governance, and the refund always returns to the
// creator:
//  1. A non-admin user creates an incentive (pending)
//  2. An unrelated stranger cannot cancel it
//  3. The creator cancels their own incentive; the refund returns to the creator
//  4. A second user creates another incentive; admin cancels it and the refund
//     still returns to that user (the creator), not to admin

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
	_ "gno.land/r/onbloc/qux"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	creatorAddr  = testutils.TestAddress("incentive-creator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	user2Addr  = testutils.TestAddress("incentive-creator-2")
	user2Realm = testing.NewUserRealm(user2Addr)

	strangerAddr  = testutils.TestAddress("stranger")
	strangerRealm = testing.NewUserRealm(strangerAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000

	firstIncentiveID  string
	secondIncentiveID string
)

func main(cur realm) {
	println("[SCENARIO] Creator can cancel their own external incentive")
	println()

	println("[SCENARIO] 1. A non-admin user creates a pending incentive")
	initialize(cur)
	firstIncentiveID = createIncentiveAs(cur, creatorAddr, 1)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(incentives))
	println()

	println("[SCENARIO] 2. An unrelated stranger cannot cancel it")
	strangerCannotCancel(cur)
	println()

	println("[SCENARIO] 3. The creator cancels their own incentive; refund returns to the creator")
	creatorCancelsOwn(cur)
	println()

	println("[SCENARIO] 4. Admin cancels a second user's incentive; refund still returns to that user")
	secondIncentiveID = createIncentiveAs(cur, user2Addr, 2)
	adminCancelsRefundsCreator(cur)
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

	// Fund the two creators so they can pay the reward and the GNS deposit.
	depositGnsAmount := sr.GetDepositGnsAmount()
	bar.Transfer(cross(cur), creatorAddr, REWARD_AMOUNT)
	bar.Transfer(cross(cur), user2Addr, REWARD_AMOUNT)
	gns.Transfer(cross(cur), creatorAddr, depositGnsAmount)
	gns.Transfer(cross(cur), user2Addr, depositGnsAmount)

	println("[INFO] created bar:qux pool and funded two creators")
}

// createIncentiveAs has the given user create an incentive and returns its id.
func createIncentiveAs(cur realm, userAddr address, counter int64) string {
	testing.SetRealm(testing.NewUserRealm(userAddr))

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	start := ((createTimestamp / 86400) + 2) * 86400 // day+2 midnight: >= now+24h
	end := start + INCENTIVE_DURATION

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, start, end)
	return ufmt.Sprintf("%s:%d:%d", userAddr, createTimestamp, counter)
}

func strangerCannotCancel(cur realm) {
	testing.SetRealm(strangerRealm)

	uassert.AbortsContains(t, cur, "must be admin, governance, or the incentive creator", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, firstIncentiveID)
	})
	println("[EXPECTED] stranger rejected: not admin, governance, or creator")
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] incentive untouched: %d\n", len(incentives))
}

func creatorCancelsOwn(cur realm) {
	barBefore := bar.BalanceOf(creatorAddr)
	gnsBefore := gns.BalanceOf(creatorAddr)

	testing.SetRealm(creatorRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, firstIncentiveID)

	ufmt.Printf("[EXPECTED] creator BAR refund delta: %d\n", bar.BalanceOf(creatorAddr)-barBefore)
	ufmt.Printf("[EXPECTED] creator GNS refund delta: %d\n", gns.BalanceOf(creatorAddr)-gnsBefore)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(incentives))
}

func adminCancelsRefundsCreator(cur realm) {
	creatorBarBefore := bar.BalanceOf(user2Addr)
	creatorGnsBefore := gns.BalanceOf(user2Addr)
	adminBarBefore := bar.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, secondIncentiveID)

	ufmt.Printf("[EXPECTED] user2 (creator) BAR refund delta: %d\n", bar.BalanceOf(user2Addr)-creatorBarBefore)
	ufmt.Printf("[EXPECTED] user2 (creator) GNS refund delta: %d\n", gns.BalanceOf(user2Addr)-creatorGnsBefore)
	ufmt.Printf("[EXPECTED] admin BAR delta (receives nothing): %d\n", bar.BalanceOf(adminAddr)-adminBarBefore)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(incentives))
}

// Output:
// [SCENARIO] Creator can cancel their own external incentive
//
// [SCENARIO] 1. A non-admin user creates a pending incentive
// [INFO] created bar:qux pool and funded two creators
// [EXPECTED] incentives for pool: 1
//
// [SCENARIO] 2. An unrelated stranger cannot cancel it
// [EXPECTED] stranger rejected: not admin, governance, or creator
// [EXPECTED] incentive untouched: 1
//
// [SCENARIO] 3. The creator cancels their own incentive; refund returns to the creator
// [EXPECTED] creator BAR refund delta: 1000000000
// [EXPECTED] creator GNS refund delta: 100000000000
// [EXPECTED] incentives for pool: 0
//
// [SCENARIO] 4. Admin cancels a second user's incentive; refund still returns to that user
// [EXPECTED] user2 (creator) BAR refund delta: 1000000000
// [EXPECTED] user2 (creator) GNS refund delta: 100000000000
// [EXPECTED] admin BAR delta (receives nothing): 0
// [EXPECTED] incentives for pool: 0
//
