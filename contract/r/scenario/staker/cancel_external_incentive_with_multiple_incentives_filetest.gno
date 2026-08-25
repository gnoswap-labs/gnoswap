// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier)
//
// POSITIONs:
// 1. Single position staked before either incentive starts
//
// SCENARIO:
// Verifies cancelling one of several incentives on the same pool leaves the
// others untouched. Both incentives share a start timestamp, so they live in the
// same start-time index bucket - the bucket must keep the surviving id:
// 1. Admin creates a BAR and a QUX incentive on the same pool, same window
// 2. User stakes while both are pending
// 3. Admin cancels the BAR incentive before the start timestamp
// 4. The QUX incentive starts and pays rewards; BAR pays nothing
// 5. The pool is still stakeable because the QUX incentive survives

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

	cancelledIncentiveID string
	survivingIncentiveID string
	startTimestamp       int64
)

func main(cur realm) {
	println("[SCENARIO] Cancel one of several incentives on the same pool")
	println()

	println("[SCENARIO] 1. Initialize and create pool")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Admin creates a BAR and a QUX incentive in the same window")
	createPendingIncentives(cur)
	println()

	println("[SCENARIO] 3. User stakes while both are pending")
	userMintThenStake(cur)
	println()

	println("[SCENARIO] 4. Admin cancels only the BAR incentive")
	cancelBarIncentive(cur)
	println()

	println("[SCENARIO] 5. Surviving incentive pays rewards after it starts")
	collectAfterStart(cur)
	println()

	println("[SCENARIO] 6. Pool is still stakeable through the surviving incentive")
	stakeAnotherPosition(cur)
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

	println("[INFO] created pool without internal tier")
}

func createPendingIncentives(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 2) * 86400 // day+2 midnight: >= now+24h to satisfy the start-time policy
	endTimestamp := startTimestamp + INCENTIVE_DURATION

	cancelledIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	survivingIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 2)

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	sr.CreateExternalIncentive(cross(cur), poolPath, quxPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
	ufmt.Printf("[INFO] both start at the same timestamp: %t\n",
		sr.GetIncentiveStartTimestamp(poolPath, cancelledIncentiveID) == sr.GetIncentiveStartTimestamp(poolPath, survivingIncentiveID))
}

func userMintThenStake(cur realm) {
	positionId := mintPosition(cur)

	testing.SetRealm(userRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(positionId)))
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[INFO] user staked position %d\n", positionId)
}

func cancelBarIncentive(cur realm) {
	// The refund is returned to the incentive creator (admin created it).
	barBefore := bar.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, cancelledIncentiveID)

	ufmt.Printf("[EXPECTED] creator BAR delta: %d\n", bar.BalanceOf(adminAddr)-barBefore)
	ufmt.Printf("[EXPECTED] creator GNS delta: %d\n", gns.BalanceOf(adminAddr)-gnsBefore)
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
	ufmt.Printf("[EXPECTED] surviving incentive reward token: %s\n", sr.GetIncentiveRewardToken(poolPath, survivingIncentiveID))
}

func collectAfterStart(cur realm) {
	// Run one third of the incentive window so a non-trivial reward accrues.
	skipToTimestamp(startTimestamp + INCENTIVE_DURATION/3)

	ufmt.Printf("[EXPECTED] collectable from surviving incentive > 0: %t\n",
		sr.CollectableExternalIncentiveReward(1, survivingIncentiveID) > 0)
	ufmt.Printf("[EXPECTED] collectable from cancelled incentive: %d\n",
		sr.CollectableExternalIncentiveReward(1, cancelledIncentiveID))

	testing.SetRealm(userRealm)
	barBefore := bar.BalanceOf(userAddr)
	quxBefore := qux.BalanceOf(userAddr)
	sr.CollectReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] user BAR delta from cancelled incentive: %d\n", bar.BalanceOf(userAddr)-barBefore)
	ufmt.Printf("[EXPECTED] user QUX delta from surviving incentive > 0: %t\n", qux.BalanceOf(userAddr)-quxBefore > 0)
}

func stakeAnotherPosition(cur realm) {
	positionId := mintPosition(cur)

	testing.SetRealm(userRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(positionId)))
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[EXPECTED] staked position %d after the cancel\n", positionId)
}

func mintPosition(cur realm) uint64 {
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

	return positionId
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
// [SCENARIO] Cancel one of several incentives on the same pool
//
// [SCENARIO] 1. Initialize and create pool
// [INFO] created pool without internal tier
//
// [SCENARIO] 2. Admin creates a BAR and a QUX incentive in the same window
// [INFO] pending incentives for pool: 2
// [INFO] both start at the same timestamp: true
//
// [SCENARIO] 3. User stakes while both are pending
// [INFO] user staked position 1
//
// [SCENARIO] 4. Admin cancels only the BAR incentive
// [EXPECTED] creator BAR delta: 1000000000
// [EXPECTED] creator GNS delta: 100000000000
// [EXPECTED] remaining incentives for pool: 1
// [EXPECTED] surviving incentive reward token: gno.land/r/onbloc/qux.QUX
//
// [SCENARIO] 5. Surviving incentive pays rewards after it starts
// [EXPECTED] collectable from surviving incentive > 0: true
// [EXPECTED] collectable from cancelled incentive: 0
// [EXPECTED] user BAR delta from cancelled incentive: 0
// [EXPECTED] user QUX delta from surviving incentive > 0: true
//
// [SCENARIO] 6. Pool is still stakeable through the surviving incentive
// [EXPECTED] staked position 2 after the cancel
//
