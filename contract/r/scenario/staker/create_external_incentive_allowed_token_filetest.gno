// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (token0 = bar, token1 = qux)
//
// POSITIONs: none
//
// SCENARIO:
// Only allowed tokens may be used as an external-incentive reward token. The
// allowed set is: the pool's own two tokens, plus the whitelist (default:
// wugnot and gns). This drives that rule through the proxy entrypoint:
//  1. A non-pool token that is not whitelisted (baz) is rejected
//  2. A pool token (bar) is accepted even though it is not on the whitelist
//  3. A whitelisted token (gns) is accepted even though it is not a pool token
//  4. After AddToken(baz), the previously rejected token is accepted

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
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
	quxPath = "gno.land/r/onbloc/qux.QUX"
	gnsPath = "gno.land/r/gnoswap/gns.GNS"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1_000_000_000

	startTimestamp int64
	endTimestamp   int64
)

func main(cur realm) {
	println("[SCENARIO] Only allowed tokens can be an external-incentive reward token")
	println()

	println("[SCENARIO] 1. Initialize and create pool")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Non-pool, non-whitelisted token is rejected")
	rejectNonAllowedToken(cur)
	println()

	println("[SCENARIO] 3. A pool token is accepted (not on the whitelist)")
	acceptPoolToken(cur)
	println()

	println("[SCENARIO] 4. A whitelisted token is accepted (not a pool token)")
	acceptWhitelistedToken(cur)
	println()

	println("[SCENARIO] 5. After AddToken, the previously rejected token is accepted")
	acceptAfterWhitelisting(cur)
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

	// day+2 midnight: >= now+24h to satisfy the start-time policy.
	createTimestamp := time.Now().Unix()
	startTimestamp = ((createTimestamp / 86400) + 2) * 86400
	endTimestamp = startTimestamp + INCENTIVE_DURATION

	// Approve every token the scenario may deposit as a reward, plus the GNS
	// deposit.
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	baz.Approve(cross(cur), stakerAddr, maxInt64)
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	println("[INFO] created bar:qux pool (token0=bar, token1=qux)")
}

func rejectNonAllowedToken(cur realm) {
	testing.SetRealm(adminRealm)

	// errNotAllowedForExternalReward: baz is neither a pool token nor whitelisted.
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-017]", func() {
		sr.CreateExternalIncentive(cross(cur), poolPath, bazPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	})
	println("[EXPECTED] baz rejected: not allowed for external reward")
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] incentives for pool: %d\n", len(incentives))
}

func acceptPoolToken(cur realm) {
	testing.SetRealm(adminRealm)

	// bar is token0 of the pool, so it is allowed even though it is not whitelisted.
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] bar (pool token) accepted; incentives for pool: %d\n", len(incentives))
}

func acceptWhitelistedToken(cur realm) {
	testing.SetRealm(adminRealm)

	// gns is not a token of bar:qux, but it is on the default whitelist.
	sr.CreateExternalIncentive(cross(cur), poolPath, gnsPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] gns (whitelisted token) accepted; incentives for pool: %d\n", len(incentives))
}

func acceptAfterWhitelisting(cur realm) {
	testing.SetRealm(adminRealm)

	sr.AddToken(cross(cur), bazPath)
	sr.CreateExternalIncentive(cross(cur), poolPath, bazPath, REWARD_AMOUNT, startTimestamp, endTimestamp)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] baz accepted after AddToken; incentives for pool: %d\n", len(incentives))
}

// Output:
// [SCENARIO] Only allowed tokens can be an external-incentive reward token
//
// [SCENARIO] 1. Initialize and create pool
// [INFO] created bar:qux pool (token0=bar, token1=qux)
//
// [SCENARIO] 2. Non-pool, non-whitelisted token is rejected
// [EXPECTED] baz rejected: not allowed for external reward
// [EXPECTED] incentives for pool: 0
//
// [SCENARIO] 3. A pool token is accepted (not on the whitelist)
// [EXPECTED] bar (pool token) accepted; incentives for pool: 1
//
// [SCENARIO] 4. A whitelisted token is accepted (not a pool token)
// [EXPECTED] gns (whitelisted token) accepted; incentives for pool: 2
//
// [SCENARIO] 5. After AddToken, the previously rejected token is accepted
// [EXPECTED] baz accepted after AddToken; incentives for pool: 3
//
