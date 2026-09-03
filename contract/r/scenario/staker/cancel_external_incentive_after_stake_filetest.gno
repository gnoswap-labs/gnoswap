// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier, so the external incentive is its only reward)
//
// POSITIONs:
// 1. Single position staked while the incentive is still pending
//
// SCENARIO:
// The full Create -> Stake -> Cancel flow with a single incentive. A position
// staked while the incentive is only pending must NOT capture a reference to it,
// so cancelling the incentive before it starts cannot leave the position with a
// dangling reference:
//  1. Admin creates one pending external incentive
//  2. User stakes a position while the incentive is pending
//  3. Admin cancels the incentive before the start timestamp
//  4. The staked position never referenced the incentive (deposit id list empty),
//     so after cancel + skipping past the start, CollectReward is a clean no-op
//     (no dangling-reference panic) and the position can still be unstaked
//  5. Because it was the pool's only incentive, a NEW StakeToken is rejected -
//     the pool is no longer incentivized

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

	incentiveID    string
	startTimestamp int64
	stakedPosition uint64
)

func main(cur realm) {
	println("[SCENARIO] Create -> Stake -> Cancel with a single incentive")
	println()

	println("[SCENARIO] 1. Admin creates one pending external incentive")
	initialize(cur)
	createPendingIncentive(cur)
	println()

	println("[SCENARIO] 2. User stakes a position while the incentive is pending")
	stakeWhilePending(cur)
	println()

	println("[SCENARIO] 3. Admin cancels the incentive before the start timestamp")
	cancelIncentive(cur)
	println()

	println("[SCENARIO] 4. Staked position has no dangling reference after cancel")
	collectAfterCancel(cur)
	println()

	println("[SCENARIO] 5. Pool is de-incentivized: a new stake is rejected")
	checkNewStakeRejected(cur)
	println()

	println("[SCENARIO] 6. Existing position can still be unstaked")
	unstakeExisting(cur)
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

	bar.Transfer(cross(cur), userAddr, 1000000)
	qux.Transfer(cross(cur), userAddr, 1000000)

	println("[INFO] created pool without internal tier")
}

func createPendingIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 2) * 86400 // day+2 midnight: >= now+24h to satisfy the start-time policy
	endTimestamp := startTimestamp + INCENTIVE_DURATION

	incentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(incentives))
}

func stakeWhilePending(cur realm) {
	stakedPosition = mintPosition(cur)

	testing.SetRealm(userRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(stakedPosition)))
	sr.StakeToken(cross(cur), stakedPosition, "")

	// The incentive is still pending (start > now), so StakeToken does not add it
	// to the deposit's incentive-id list.
	ids, err := sr.GetDepositExternalIncentiveIdList(stakedPosition)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[INFO] staked position %d\n", stakedPosition)
	ufmt.Printf("[EXPECTED] deposit references the pending incentive: %t\n", len(ids) != 0)
}

func cancelIncentive(cur realm) {
	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID)

	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(incentives))
}

func collectAfterCancel(cur realm) {
	// Skip well past the (now-removed) incentive's start timestamp.
	skipToTimestamp(startTimestamp + INCENTIVE_DURATION/3)

	// The deposit never referenced the pending incentive, so collecting is a
	// clean no-op and must not panic on a removed incentive id.
	ids, err := sr.GetDepositExternalIncentiveIdList(stakedPosition)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] deposit incentive-id count after cancel: %d\n", len(ids))

	testing.SetRealm(userRealm)
	barBefore := bar.BalanceOf(userAddr)
	uassert.NotPanics(t, cur, func() {
		sr.CollectReward(cross(cur), stakedPosition)
	})
	ufmt.Printf("[EXPECTED] CollectReward did not panic; BAR delta: %d\n", bar.BalanceOf(userAddr)-barBefore)
}

func checkNewStakeRejected(cur realm) {
	newPosition := mintPosition(cur)

	testing.SetRealm(userRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(newPosition)))

	// errNonIncentivizedPool
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-007]", func() {
		sr.StakeToken(cross(cur), newPosition, "")
	})
	println("[EXPECTED] new stake rejected: pool is not incentivized")
}

func unstakeExisting(cur realm) {
	testing.SetRealm(userRealm)
	sr.UnStakeToken(cross(cur), stakedPosition)
	ufmt.Printf("[EXPECTED] position %d unstaked after the cancel\n", stakedPosition)
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
		"100000",
		"100000",
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

func positionIdFrom(cur realm, id int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(id))
}

// Output:
// [SCENARIO] Create -> Stake -> Cancel with a single incentive
//
// [SCENARIO] 1. Admin creates one pending external incentive
// [INFO] created pool without internal tier
// [INFO] pending incentives for pool: 1
//
// [SCENARIO] 2. User stakes a position while the incentive is pending
// [INFO] staked position 1
// [EXPECTED] deposit references the pending incentive: false
//
// [SCENARIO] 3. Admin cancels the incentive before the start timestamp
// [EXPECTED] remaining incentives for pool: 0
//
// [SCENARIO] 4. Staked position has no dangling reference after cancel
// [EXPECTED] deposit incentive-id count after cancel: 0
// [EXPECTED] CollectReward did not panic; BAR delta: 0
//
// [SCENARIO] 5. Pool is de-incentivized: a new stake is rejected
// [EXPECTED] new stake rejected: pool is not incentivized
//
// [SCENARIO] 6. Existing position can still be unstaked
// [EXPECTED] position 1 unstaked after the cancel
//
