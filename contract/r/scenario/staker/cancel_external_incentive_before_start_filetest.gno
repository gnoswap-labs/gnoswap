// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier, so the external incentive is its only reward)
//
// POSITIONs:
// 1. Single position staked while the incentive is still pending
//
// SCENARIO:
// Verifies CancelExternalIncentive removes a not-yet-started external incentive
// and refunds everything the creator paid:
// 1. Create a pool without an internal tier
// 2. Admin creates a 90-day external incentive starting at the next midnight
// 3. A position can be staked while the incentive is pending
// 4. Admin cancels before the start timestamp; reward tokens and the GNS
//    deposit both go to the refundee
// 5. The incentive is gone from the pool, so a new stake is rejected as
//    non-incentivized while the existing position can still be unstaked
// 6. Cancelling the same incentive again aborts

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
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
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("user1")
	userUser  = userAddr
	userRealm = testing.NewUserRealm(userAddr)

	refundeeAddr = testutils.TestAddress("refundee")
	refundeeUser = refundeeAddr

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000     // 1000 BAR

	incentiveID string
)

func main(cur realm) {
	println("[SCENARIO] Cancel an external incentive before it starts")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create pool without internal tier")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Admin creates a pending external incentive")
	createPendingIncentive(cur)
	println()

	println("[SCENARIO] 4. User stakes while the incentive is pending")
	userMintThenStake(cur)
	println()

	println("[SCENARIO] 5. Admin cancels the incentive before it starts")
	cancelIncentive(cur)
	println()

	println("[SCENARIO] 6. Pool is no longer incentivized")
	checkPoolNotIncentivized(cur)
	println()

	println("[SCENARIO] 7. Existing position can still be unstaked")
	unstakeExistingPosition(cur)
	println()

	println("[SCENARIO] 8. Cancelling the same incentive again aborts")
	checkSecondCancelAborts(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)
	testing.SkipHeights(1)

	bar.Transfer(cross(cur), userUser, 10000)
	qux.Transfer(cross(cur), userUser, 10000)

	println("[INFO] initialized accounts")
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

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

func createPendingIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()

	// Start at the next UTC midnight to satisfy start-time validation, so the
	// incentive is still pending right after creation.
	startTime := ((createTimestamp / 86400) + 1) * 86400
	endTime := startTime + INCENTIVE_DURATION

	incentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)

	sr.CreateExternalIncentive(
		cross(cur),
		poolPath,
		barPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	incentives := sr.GetExternalIncentiveByPoolPath(poolPath)
	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(incentives))
	ufmt.Printf("[INFO] incentive starts in %d seconds\n", startTime-time.Now().Unix())
}

func userMintThenStake(cur realm) {
	testing.SetRealm(userRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		userAddr,
		"",
	)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(lpTokenId)))
	sr.StakeToken(cross(cur), lpTokenId, "")

	ufmt.Printf("[INFO] user staked position %d\n", lpTokenId)
}

func cancelIncentive(cur realm) {
	depositGnsAmount := sr.GetDepositGnsAmount()

	barBefore := bar.BalanceOf(refundeeUser)
	gnsBefore := gns.BalanceOf(refundeeUser)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID, refundeeUser)

	ufmt.Printf("[EXPECTED] refundee BAR delta: %d (reward amount: %d)\n", bar.BalanceOf(refundeeUser)-barBefore, REWARD_AMOUNT)
	ufmt.Printf("[EXPECTED] refundee GNS delta: %d (deposit amount: %d)\n", gns.BalanceOf(refundeeUser)-gnsBefore, depositGnsAmount)
}

func checkPoolNotIncentivized(cur realm) {
	incentives := sr.GetExternalIncentiveByPoolPath(poolPath)
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(incentives))

	// Getters resolve the incentive by id, so a cancelled incentive reads as if
	// it had never been created.
	uassert.AbortsContains(t, cur, "does not exist", func() {
		sr.GetIncentiveEndTimestamp(poolPath, incentiveID)
	})
	println("[EXPECTED] incentive getters no longer resolve the cancelled id")

	testing.SetRealm(userRealm)
	lpTokenId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		userAddr,
		"",
	)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(lpTokenId)))

	// errNonIncentivizedPool
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-007]", func() {
		sr.StakeToken(cross(cur), lpTokenId, "")
	})
	println("[EXPECTED] new stake rejected: pool is not incentivized")
}

func unstakeExistingPosition(cur realm) {
	testing.SetRealm(userRealm)

	sr.UnStakeToken(cross(cur), 1)
	println("[EXPECTED] position 1 unstaked after the incentive was cancelled")
}

func checkSecondCancelAborts(cur realm) {
	testing.SetRealm(adminRealm)

	// errCannotCancelIncentive
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-023]", func() {
		sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID, refundeeUser)
	})
	println("[EXPECTED] second cancel rejected: incentive no longer exists")
}

func positionIdFrom(cur realm, positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Cancel an external incentive before it starts
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool without internal tier
// [INFO] created pool without internal tier
//
// [SCENARIO] 3. Admin creates a pending external incentive
// [INFO] pending incentives for pool: 1
// [INFO] incentive starts in 1700 seconds
//
// [SCENARIO] 4. User stakes while the incentive is pending
// [INFO] user staked position 1
//
// [SCENARIO] 5. Admin cancels the incentive before it starts
// [EXPECTED] refundee BAR delta: 1000000000 (reward amount: 1000000000)
// [EXPECTED] refundee GNS delta: 1000000000 (deposit amount: 1000000000)
//
// [SCENARIO] 6. Pool is no longer incentivized
// [EXPECTED] remaining incentives for pool: 0
// [EXPECTED] incentive getters no longer resolve the cancelled id
// [EXPECTED] new stake rejected: pool is not incentivized
//
// [SCENARIO] 7. Existing position can still be unstaked
// [EXPECTED] position 1 unstaked after the incentive was cancelled
//
// [SCENARIO] 8. Cancelling the same incentive again aborts
// [EXPECTED] second cancel rejected: incentive no longer exists
//
