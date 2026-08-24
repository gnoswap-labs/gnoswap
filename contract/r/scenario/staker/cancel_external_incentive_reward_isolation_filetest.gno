// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier, so external incentives are the only rewards)
//
// POSITIONs:
// 1. Single position staked before either incentive starts
//
// SCENARIO:
// Cancelling one incentive before it starts must not leak into the reward flow
// of another incentive on the same pool:
//  1. Admin creates two external incentives (BAR and QUX) on the same window
//  2. User mints a position and stakes it while both are still pending
//  3. Admin cancels the BAR incentive before the start timestamp
//  4. Skip past the start timestamp so the surviving incentive is live
//  5. CollectReward pays exactly the collectable QUX amount (the active
//     incentive), while the cancelled BAR incentive moves nothing

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

	cancelledIncentiveID string // BAR reward
	activeIncentiveID    string // QUX reward
	startTimestamp       int64
	positionId           uint64
)

func main(cur realm) {
	println("[SCENARIO] Cancelled incentive is isolated from the surviving reward flow")
	println()

	println("[SCENARIO] 1. Admin creates a BAR and a QUX incentive on the same window")
	initialize(cur)
	createPendingIncentives(cur)
	println()

	println("[SCENARIO] 2. User mints and stakes a position while both are pending")
	userMintThenStake(cur)
	println()

	println("[SCENARIO] 3. Admin cancels the BAR incentive before the start timestamp")
	cancelBarIncentive(cur)
	println()

	println("[SCENARIO] 4. Skip past the start timestamp")
	skipPastStart(cur)
	println()

	println("[SCENARIO] 5. CollectReward pays the active incentive only")
	collectAndVerify(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0) // fee 0 so collectable equals received amount
	pl.SetPoolCreationFee(cross(cur), 0)
	testing.SkipHeights(1)

	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	bar.Transfer(cross(cur), userAddr, 100000)
	qux.Transfer(cross(cur), userAddr, 100000)

	println("[INFO] created pool without internal tier")
}

func createPendingIncentives(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 1) * 86400
	endTimestamp := startTimestamp + INCENTIVE_DURATION

	cancelledIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	activeIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 2)

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	sr.CreateExternalIncentive(cross(cur), poolPath, quxPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
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
		"100000",
		"100000",
		"1",
		"1",
		maxTimeout,
		userAddr,
		"",
	)
	positionId = lpTokenId

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(positionId)))
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[INFO] user staked position %d\n", positionId)
}

func cancelBarIncentive(cur realm) {
	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, cancelledIncentiveID, refundeeAddr)

	ufmt.Printf("[INFO] remaining incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
	ufmt.Printf("[INFO] surviving incentive reward token: %s\n", sr.GetIncentiveRewardToken(poolPath, activeIncentiveID))
}

func skipPastStart(cur realm) {
	// Run one third of the incentive window so a non-trivial reward accrues.
	skipToTimestamp(startTimestamp + INCENTIVE_DURATION/3)
	ufmt.Printf("[INFO] chain time is past the start: %t\n", time.Now().Unix() > startTimestamp)
}

func collectAndVerify(cur realm) {
	// Collectable is read at the same block as the collect, so with the
	// unstaking fee set to 0 the user receives exactly this amount.
	collectableQux := sr.CollectableExternalIncentiveReward(positionId, activeIncentiveID)
	collectableBar := sr.CollectableExternalIncentiveReward(positionId, cancelledIncentiveID)

	ufmt.Printf("[EXPECTED] collectable from active (QUX) incentive > 0: %t\n", collectableQux > 0)
	ufmt.Printf("[EXPECTED] collectable from cancelled (BAR) incentive: %d\n", collectableBar)

	testing.SetRealm(userRealm)
	barBefore := bar.BalanceOf(userAddr)
	quxBefore := qux.BalanceOf(userAddr)

	sr.CollectReward(cross(cur), positionId)

	barDelta := bar.BalanceOf(userAddr) - barBefore
	quxDelta := qux.BalanceOf(userAddr) - quxBefore

	// Active incentive: the received amount matches the reported collectable exactly.
	uassert.True(t, quxDelta > 0)
	uassert.Equal(t, collectableQux, quxDelta)
	ufmt.Printf("[EXPECTED] QUX received equals collectable: %t\n", quxDelta == collectableQux)

	// Cancelled incentive: no BAR flows during the collect.
	uassert.Equal(t, int64(0), barDelta)
	ufmt.Printf("[EXPECTED] BAR delta from the cancelled incentive: %d\n", barDelta)

	// The surviving incentive is what got drained: its distributed amount tracks
	// exactly the reward handed to the user (the remaining amount also drops by
	// the warmup penalty, so distributed is the clean invariant here).
	distributed := sr.GetIncentiveDistributedRewardAmount(poolPath, activeIncentiveID)
	uassert.Equal(t, quxDelta, distributed)
	ufmt.Printf("[EXPECTED] active incentive distributed == QUX received: %t\n", distributed == quxDelta)
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

func positionIdFrom(cur realm, id int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(id))
}

// Output:
// [SCENARIO] Cancelled incentive is isolated from the surviving reward flow
//
// [SCENARIO] 1. Admin creates a BAR and a QUX incentive on the same window
// [INFO] created pool without internal tier
// [INFO] pending incentives for pool: 2
//
// [SCENARIO] 2. User mints and stakes a position while both are pending
// [INFO] user staked position 1
//
// [SCENARIO] 3. Admin cancels the BAR incentive before the start timestamp
// [INFO] remaining incentives for pool: 1
// [INFO] surviving incentive reward token: gno.land/r/onbloc/qux.QUX
//
// [SCENARIO] 4. Skip past the start timestamp
// [INFO] chain time is past the start: true
//
// [SCENARIO] 5. CollectReward pays the active incentive only
// [EXPECTED] collectable from active (QUX) incentive > 0: true
// [EXPECTED] collectable from cancelled (BAR) incentive: 0
// [EXPECTED] QUX received equals collectable: true
// [EXPECTED] BAR delta from the cancelled incentive: 0
// [EXPECTED] active incentive distributed == QUX received: true
//
