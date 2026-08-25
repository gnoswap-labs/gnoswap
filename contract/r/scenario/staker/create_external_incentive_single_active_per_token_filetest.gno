// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs: none
//
// SCENARIO:
// A pool may hold at most one *unfinished* external incentive per reward token.
// An incentive is unfinished while currentTime <= endTimestamp (i.e. pending or
// active, up to and including the end boundary); it is finished only strictly
// after its end. This drives the rule and its boundaries through the proxy:
//  1. Create a bar incentive (pending)
//  2. A second bar incentive is rejected while the first is still pending
//  3. A qux incentive (different token) is accepted on the same pool
//  4. After the first bar incentive becomes active, a second bar is still rejected
//  5. Past the first bar incentive's end, a new bar incentive is accepted

package main

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
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

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000

	firstBarStart int64
	firstBarEnd   int64
)

func main(cur realm) {
	println("[SCENARIO] At most one unfinished incentive per reward token")
	println()

	println("[SCENARIO] 1. Create the first bar incentive (pending)")
	initialize(cur)
	createFirstBar(cur)
	println()

	println("[SCENARIO] 2. A second bar incentive is rejected while pending (before start)")
	rejectSecondBarWhilePending(cur)
	println()

	println("[SCENARIO] 3. A qux incentive (different token) is accepted")
	acceptDifferentToken(cur)
	println()

	println("[SCENARIO] 4. A second bar incentive is rejected while active")
	rejectSecondBarWhileActive(cur)
	println()

	println("[SCENARIO] 5. A new bar incentive is accepted after the first one ends")
	acceptBarAfterEnd(cur)
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
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	println("[INFO] created bar:qux pool")
}

func createFirstBar(cur realm) {
	testing.SetRealm(adminRealm)

	firstBarStart = nextValidStart()
	firstBarEnd = firstBarStart + INCENTIVE_DURATION

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, firstBarStart, firstBarEnd)
	ufmt.Printf("[EXPECTED] bar incentive created; incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func rejectSecondBarWhilePending(cur realm) {
	testing.SetRealm(adminRealm)

	start := nextValidStart()
	// errIncentiveAlreadyExists: bar already has an unfinished (pending) incentive.
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-018]", func() {
		sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, start, start+INCENTIVE_DURATION)
	})
	println("[EXPECTED] second bar rejected while first is pending")
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func acceptDifferentToken(cur realm) {
	testing.SetRealm(adminRealm)

	start := nextValidStart()
	sr.CreateExternalIncentive(cross(cur), poolPath, quxPath, REWARD_AMOUNT, start, start+INCENTIVE_DURATION)
	ufmt.Printf("[EXPECTED] qux (different token) accepted; incentives for pool: %d\n", len(sr.GetExternalIncentiveByPoolPath(poolPath)))
}

func rejectSecondBarWhileActive(cur realm) {
	// Advance to the middle of the first bar incentive's active window.
	skipToTimestamp(firstBarStart + INCENTIVE_DURATION/2)
	ufmt.Printf("[INFO] first bar incentive active: %t\n", time.Now().Unix() >= firstBarStart && time.Now().Unix() <= firstBarEnd)

	testing.SetRealm(adminRealm)
	start := nextValidStart()
	// errIncentiveAlreadyExists: bar's first incentive is still unfinished.
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-018]", func() {
		sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, start, start+INCENTIVE_DURATION)
	})
	println("[EXPECTED] second bar rejected while first is active")
}

func acceptBarAfterEnd(cur realm) {
	// Advance strictly past the first bar incentive's end. A one-day margin keeps
	// this robust against block-time flooring. The exact-end boundary (currentTime
	// == end is still "unfinished") is pinned by the unit test
	// TestAssertIsExternalRewardTokenAvailable ("same token at exact end time").
	skipToTimestamp(firstBarEnd + 86400)
	ufmt.Printf("[INFO] first bar incentive ended: %t\n", time.Now().Unix() > firstBarEnd)

	testing.SetRealm(adminRealm)
	start := nextValidStart()
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, start, start+INCENTIVE_DURATION)
	println("[EXPECTED] new bar incentive accepted after the first one ended")
}

// nextValidStart returns the day-after-tomorrow midnight from the current chain
// time (>= now+24h and midnight), satisfying the start-time policy.
func nextValidStart() int64 {
	return ((time.Now().Unix() / 86400) + 2) * 86400
}

// skipToTimestamp advances the chain to the last block at or before the target.
func skipToTimestamp(target int64) {
	remaining := target - time.Now().Unix()
	if remaining < 5 {
		return
	}
	testing.SkipHeights(remaining / 5)
}

// Output:
// [SCENARIO] At most one unfinished incentive per reward token
//
// [SCENARIO] 1. Create the first bar incentive (pending)
// [INFO] created bar:qux pool
// [EXPECTED] bar incentive created; incentives for pool: 1
//
// [SCENARIO] 2. A second bar incentive is rejected while pending (before start)
// [EXPECTED] second bar rejected while first is pending
// [EXPECTED] incentives for pool: 1
//
// [SCENARIO] 3. A qux incentive (different token) is accepted
// [EXPECTED] qux (different token) accepted; incentives for pool: 2
//
// [SCENARIO] 4. A second bar incentive is rejected while active
// [INFO] first bar incentive active: true
// [EXPECTED] second bar rejected while first is active
//
// [SCENARIO] 5. A new bar incentive is accepted after the first one ends
// [INFO] first bar incentive ended: true
// [EXPECTED] new bar incentive accepted after the first one ended
//
