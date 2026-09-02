// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (no internal tier, so the external incentive is its only reward)
//
// POSITIONs:
// 1. Single position staked while the incentive is still pending
//
// SCENARIO:
// The Create -> Stake -> Cancel -> UnStake flow with a single incentive.
// UnStakeToken internally collects rewards before returning the NFT, so this
// exercises the collect-inside-unstake path directly against a cancelled
// incentive:
//  1. Admin creates one pending external incentive
//  2. User stakes a position while the incentive is pending
//  3. Admin cancels the incentive before the start timestamp (reward + GNS
//     deposit refunded to the creator)
//  4. User unstakes directly (no separate CollectReward): the NFT returns to the
//     owner, no reward is paid (the deposit never referenced the incentive), and
//     the collect-inside-unstake does not panic on the removed incentive

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
	println("[SCENARIO] Create -> Stake -> Cancel -> UnStake with a single incentive")
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

	println("[SCENARIO] 4. User unstakes directly after the cancel")
	unstakeAfterCancel(cur)
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

	owner, _ := gnft.OwnerOf(positionIdFrom(cur, int(stakedPosition)))
	ufmt.Printf("[INFO] staked position %d\n", stakedPosition)
	ufmt.Printf("[EXPECTED] NFT held by staker after stake: %t\n", owner == stakerAddr)
}

func cancelIncentive(cur realm) {
	// The refund is returned to the incentive creator (admin created it).
	creatorBarBefore := bar.BalanceOf(adminAddr)
	creatorGnsBefore := gns.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	sr.CancelExternalIncentive(cross(cur), poolPath, incentiveID)

	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(incentives))
	ufmt.Printf("[EXPECTED] creator BAR (reward) refunded: %d\n", bar.BalanceOf(adminAddr)-creatorBarBefore)
	ufmt.Printf("[EXPECTED] creator GNS (deposit) refunded: %d\n", gns.BalanceOf(adminAddr)-creatorGnsBefore)
}

func unstakeAfterCancel(cur realm) {
	// Skip past the (now-removed) incentive's start so the collect inside unstake
	// runs over what would have been the active window.
	skipToTimestamp(startTimestamp + INCENTIVE_DURATION/3)

	testing.SetRealm(userRealm)
	userBarBefore := bar.BalanceOf(userAddr)

	// UnStakeToken collects rewards before returning the NFT; it must not panic
	// on the cancelled incentive and must pay no reward.
	uassert.NotPanics(t, cur, func() {
		sr.UnStakeToken(cross(cur), stakedPosition)
	})

	owner, _ := gnft.OwnerOf(positionIdFrom(cur, int(stakedPosition)))
	ufmt.Printf("[EXPECTED] NFT returned to owner after unstake: %t\n", owner == userAddr)
	ufmt.Printf("[EXPECTED] user BAR reward from the cancelled incentive: %d\n", bar.BalanceOf(userAddr)-userBarBefore)
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
// [SCENARIO] Create -> Stake -> Cancel -> UnStake with a single incentive
//
// [SCENARIO] 1. Admin creates one pending external incentive
// [INFO] created pool without internal tier
// [INFO] pending incentives for pool: 1
//
// [SCENARIO] 2. User stakes a position while the incentive is pending
// [INFO] staked position 1
// [EXPECTED] NFT held by staker after stake: true
//
// [SCENARIO] 3. Admin cancels the incentive before the start timestamp
// [EXPECTED] remaining incentives for pool: 0
// [EXPECTED] creator BAR (reward) refunded: 1000000000
// [EXPECTED] creator GNS (deposit) refunded: 100000000000
//
// [SCENARIO] 4. User unstakes directly after the cancel
// [EXPECTED] NFT returned to owner after unstake: true
// [EXPECTED] user BAR reward from the cancelled incentive: 0
//
