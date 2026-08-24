// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier)
//
// POSITIONs:
// 1. Single position staked under the re-created incentive
//
// SCENARIO:
// Cancelling is the recovery path for an incentive created with wrong terms, so
// the pool must accept a corrected one right after:
// 1. Admin creates an incentive with the wrong reward token
// 2. Admin cancels it before the start timestamp
// 3. Admin creates a replacement on the same pool and window; the incentive
//    counter keeps advancing, so the replacement gets a fresh id
// 4. A position staked under the replacement collects the correct token

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	testutils "gno.land/p/nt/testutils/v0"
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

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("user1")
	userRealm = testing.NewUserRealm(userAddr)

	refundeeAddr = testutils.TestAddress("refundee")

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000

	wrongIncentiveID   string
	correctIncentiveID string
	startTimestamp     int64
	endTimestamp       int64
)

func main(cur realm) {
	println("[SCENARIO] Cancel a misconfigured incentive and create a replacement")
	println()

	println("[SCENARIO] 1. Initialize and create pool")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Admin creates an incentive with the wrong reward token")
	createWrongIncentive(cur)
	println()

	println("[SCENARIO] 3. Admin cancels it before the start timestamp")
	cancelWrongIncentive(cur)
	println()

	println("[SCENARIO] 4. Admin creates the replacement on the same window")
	createCorrectIncentive(cur)
	println()

	println("[SCENARIO] 5. Position staked under the replacement collects QUX")
	stakeAndCollect(cur)
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

	bar.Transfer(cross(cur), userAddr, 10000)
	qux.Transfer(cross(cur), userAddr, 10000)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	println("[INFO] created pool without internal tier")
}

func createWrongIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 1) * 86400
	endTimestamp = startTimestamp + INCENTIVE_DURATION

	wrongIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[INFO] reward token: %s\n", sr.GetIncentiveRewardToken(poolPath, wrongIncentiveID))
}

func cancelWrongIncentive(cur realm) {
	barBefore := bar.BalanceOf(refundeeAddr)
	gnsBefore := gns.BalanceOf(refundeeAddr)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, wrongIncentiveID, refundeeAddr)

	ufmt.Printf("[EXPECTED] refundee BAR delta: %d\n", bar.BalanceOf(refundeeAddr)-barBefore)
	ufmt.Printf("[EXPECTED] refundee GNS delta: %d\n", gns.BalanceOf(refundeeAddr)-gnsBefore)
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func createCorrectIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	createTimestamp := time.Now().Unix()
	correctIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 2)
	sr.CreateExternalIncentive(cross(cur), poolPath, quxPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[EXPECTED] replacement id differs from the cancelled one: %t\n", correctIncentiveID != wrongIncentiveID)
	ufmt.Printf("[EXPECTED] reward token: %s\n", sr.GetIncentiveRewardToken(poolPath, correctIncentiveID))
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func stakeAndCollect(cur realm) {
	testing.SetRealm(userRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	testing.SkipHeights(1)
	positionId, _, _, _ := pn.Mint(
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

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(positionId)))
	sr.StakeToken(cross(cur), positionId, "")
	ufmt.Printf("[INFO] user staked position %d\n", positionId)

	// Run one third of the incentive window so a non-trivial reward accrues.
	skipToTimestamp(startTimestamp + INCENTIVE_DURATION/3)

	testing.SetRealm(userRealm)
	barBefore := bar.BalanceOf(userAddr)
	quxBefore := qux.BalanceOf(userAddr)
	sr.CollectReward(cross(cur), positionId)

	ufmt.Printf("[EXPECTED] user QUX delta > 0: %t\n", qux.BalanceOf(userAddr)-quxBefore > 0)
	ufmt.Printf("[EXPECTED] user BAR delta from the cancelled incentive: %d\n", bar.BalanceOf(userAddr)-barBefore)
}

// skipToTimestamp advances the chain to the last block at or before the given
// unix timestamp.
func skipToTimestamp(target int64) {
	remaining := target - time.Now().Unix()
	if remaining < 5 {
		return
	}

	testing.SkipHeights(remaining / 5)
}

func positionIdFrom(cur realm, positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Cancel a misconfigured incentive and create a replacement
//
// [SCENARIO] 1. Initialize and create pool
// [INFO] created pool without internal tier
//
// [SCENARIO] 2. Admin creates an incentive with the wrong reward token
// [INFO] reward token: gno.land/r/onbloc/bar.BAR
//
// [SCENARIO] 3. Admin cancels it before the start timestamp
// [EXPECTED] refundee BAR delta: 1000000000
// [EXPECTED] refundee GNS delta: 1000000000
// [EXPECTED] incentives for pool: 0
//
// [SCENARIO] 4. Admin creates the replacement on the same window
// [EXPECTED] replacement id differs from the cancelled one: true
// [EXPECTED] reward token: gno.land/r/onbloc/qux.QUX
// [EXPECTED] incentives for pool: 1
//
// [SCENARIO] 5. Position staked under the replacement collects QUX
// [INFO] user staked position 1
// [EXPECTED] user QUX delta > 0: true
// [EXPECTED] user BAR delta from the cancelled incentive: 0
//
