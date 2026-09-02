// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs:
// 1. Single position repeatedly staked/unstaked during the incentive window,
//    producing multiple disjoint unclaimable periods.
//
// SCENARIO:
// Regression test for M-04: unbounded unclaimable-period tracking used to make
// external incentive refunds unexecutable. Unclaimable periods are now folded
// into a per-incentive seconds accumulator in O(1), so EndExternalIncentive
// must refund the union of ALL unclaimable gaps (not just the latest one),
// keep the accounting invariant
//   TotalRewardAmount == RewardAmount + DistributedRewardAmount + AccumulatedPenaltyAmount
// intact, and actually transfer the refunded reward tokens.
//
// 1. Create a 90-day external incentive and stake a position at the start.
// 2. Run three stake/unstake cycles, leaving unclaimable gaps of
//    10d + 5d + 3d = 18 days inside the incentive window.
// 3. Skip past incentive end without collecting.
// 4. Creator calls EndExternalIncentive to refund the union of all gaps.
// 5. Verify the refund equals 18 days of rewards (1000/sec), the accounting
//    invariant holds, and the creator received the refunded reward tokens.
// 6. The still-staked position collects its legitimate rewards afterwards.

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
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
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("user1")
	userUser  = userAddr
	userRealm = testing.NewUserRealm(userAddr)

	externalCreatorAddr = testutils.TestAddress("externalCreator")
	externalCreatorUser = externalCreatorAddr

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"
	gnsPath = "gno.land/r/gnoswap/gns.GNS"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 100_000_000_000

	// 1000 reward tokens per second, so unclaimable seconds map 1:1 to wei.
	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 7_776_000_000     // divides evenly: 1000/sec

	// stake/unstake cycle layout inside the 90-day window
	STAKE_RUN_1 int64 = 10 * 24 * 60 * 60
	GAP_1       int64 = 10 * 24 * 60 * 60
	STAKE_RUN_2 int64 = 5 * 24 * 60 * 60
	GAP_2       int64 = 5 * 24 * 60 * 60
	STAKE_RUN_3 int64 = 5 * 24 * 60 * 60
	GAP_3       int64 = 3 * 24 * 60 * 60

	// remaining time staked from the last restake until incentive end
	FINAL_STAKE int64 = INCENTIVE_DURATION - STAKE_RUN_1 - GAP_1 - STAKE_RUN_2 - GAP_2 - STAKE_RUN_3 - GAP_3

	// expected refund = union of all gaps (18 days) at 1000/sec
	EXPECTED_REFUND int64 = (GAP_1 + GAP_2 + GAP_3) * 1000
	// allow a few seconds of block-timestamp drift on each transition
	REFUND_TOLERANCE int64 = 120 * 1000

	actualIncentiveID string
	targetPoolPath    = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"
)

func main(cur realm) {
	println("[SCENARIO] External incentive refund executes with multiple unclaimable periods")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier(cur)
	println()

	println("[SCENARIO] 3. Create external incentive and stake at start")
	createAndStartIncentive(cur)
	println()

	println("[SCENARIO] 4. Run stake/unstake cycles to build unclaimable gaps")
	runStakeUnstakeCycles(cur)
	println()

	println("[SCENARIO] 5. Skip until after incentive end (no collect)")
	skipUntilAfterEnd(cur)
	println()

	println("[SCENARIO] 6. Creator ends incentive (refund path)")
	creatorGnsBefore := gns.BalanceOf(externalCreatorUser)
	endExternalIncentive(cur)
	println()

	println("[SCENARIO] 7. Verify refund accounts for ALL unclaimable periods")
	verifyRefundAccounting(cur)
	println()

	println("[SCENARIO] 8. Creator received the refunded reward tokens")
	verifyRefundTransfer(cur, creatorGnsBefore)
	println()

	println("[SCENARIO] 9. Staked user still collects their legitimate share")
	collectExternalIncentive(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)
	testing.SkipHeights(1)

	bar.Transfer(cross(cur), userUser, 10000)
	qux.Transfer(cross(cur), userUser, 10000)

	gns.Transfer(cross(cur), externalCreatorUser, REWARD_AMOUNT+depositGnsAmount)

	println("[INFO] initialized accounts")
}

func createPoolAndSetTier(cur realm) {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	sr.SetPoolTier(cross(cur), targetPoolPath, 1)
	println("[INFO] created pool and set tier")
}

func createAndStartIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()

	// Start at the first UTC midnight past the 24h minimum to satisfy start-time validation
	startTime := ((createTimestamp / 86400) + 2) * 86400
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)

	sr.CreateExternalIncentive(
		cross(cur),
		targetPoolPath,
		gnsPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Move chain time to incentive start, then stake immediately so the whole
	// window is claimable except for the deliberate unstake gaps below.
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	if timeLeft > 0 {
		testing.SkipHeights(timeLeft / 5)
	}

	ufmt.Printf("[INFO] created external incentive %s\n", actualIncentiveID)
}

func userMintThenStake(cur realm) uint64 {
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

	return lpTokenId
}

func runStakeUnstakeCycles(cur realm) {
	// stake at incentive start
	lpTokenId := userMintThenStake(cur)
	ufmt.Printf("[INFO] user staked position %d at incentive start\n", lpTokenId)

	// cycle 1: stake 10d, unstake, leave a 10d gap
	testing.SkipHeights(STAKE_RUN_1 / 5)
	sr.UnStakeToken(cross(cur), lpTokenId)
	ufmt.Printf("[INFO] unstaked after %d seconds (gap %d starts)\n", STAKE_RUN_1, GAP_1)
	testing.SkipHeights(GAP_1 / 5)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(lpTokenId)))
	sr.StakeToken(cross(cur), lpTokenId, "")
	ufmt.Printf("[INFO] restaked (gap %d ends)\n", GAP_1)

	// cycle 2: stake 5d, unstake, leave a 5d gap
	testing.SkipHeights(STAKE_RUN_2 / 5)
	sr.UnStakeToken(cross(cur), lpTokenId)
	ufmt.Printf("[INFO] unstaked after %d seconds (gap %d starts)\n", STAKE_RUN_2, GAP_2)
	testing.SkipHeights(GAP_2 / 5)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(lpTokenId)))
	sr.StakeToken(cross(cur), lpTokenId, "")
	ufmt.Printf("[INFO] restaked (gap %d ends)\n", GAP_2)

	// cycle 3: stake 5d, unstake, leave a 3d gap
	testing.SkipHeights(STAKE_RUN_3 / 5)
	sr.UnStakeToken(cross(cur), lpTokenId)
	ufmt.Printf("[INFO] unstaked after %d seconds (gap %d starts)\n", STAKE_RUN_3, GAP_3)
	testing.SkipHeights(GAP_3 / 5)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, int(lpTokenId)))
	sr.StakeToken(cross(cur), lpTokenId, "")
	ufmt.Printf("[INFO] restaked (gap %d ends)\n", GAP_3)

	// stay staked until incentive end
	testing.SkipHeights(FINAL_STAKE / 5)
	ufmt.Printf("[INFO] position stays staked for the final %d seconds\n", FINAL_STAKE)
}

func skipUntilAfterEnd(cur realm) {
	// 1-day buffer past end while still staked
	testing.SkipHeights((24 * 60 * 60) / 5)
	println("[INFO] skipped to after incentive end without collecting")
}

func endExternalIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	sr.EndExternalIncentive(
		cross(cur),
		targetPoolPath,
		actualIncentiveID,
		externalCreatorUser,
	)

	println("[INFO] external incentive ended via refund path")
}

func verifyRefundAccounting(cur realm) {
	total, _ := sr.GetIncentiveTotalRewardAmount(targetPoolPath, actualIncentiveID)
	remaining, _ := sr.GetIncentiveRemainingRewardAmount(targetPoolPath, actualIncentiveID)
	distributed, _ := sr.GetIncentiveDistributedRewardAmount(targetPoolPath, actualIncentiveID)
	penalty, _ := sr.GetIncentiveAccumulatedPenaltyAmount(targetPoolPath, actualIncentiveID)

	sum := remaining + distributed + penalty

	ufmt.Printf("[INFO] TotalRewardAmount: %d\n", total)
	ufmt.Printf("[INFO] RemainingRewardAmount: %d\n", remaining)
	ufmt.Printf("[INFO] DistributedRewardAmount: %d\n", distributed)
	ufmt.Printf("[INFO] AccumulatedPenaltyAmount: %d\n", penalty)
	ufmt.Printf("[RESULT] remaining+distributed+penalty == total: %t (%d == %d)\n", sum == total, sum, total)

	// DistributedRewardAmount aggregates the refund (union of all unclaimable
	// gaps) plus the rewards the position collected during the unstake cycles,
	// so it must be at least the full expected refund.
	minDistributed := EXPECTED_REFUND - REFUND_TOLERANCE
	distributedCovers := distributed >= minDistributed
	ufmt.Printf("[RESULT] distributed >= union of all unclaimable gaps: %t (%d >= %d)\n", distributedCovers, distributed, minDistributed)

	if sum != total {
		panic("accounting invariant broken: remaining+distributed+penalty != total")
	}
	if !distributedCovers {
		panic("refund does not cover the union of all unclaimable gaps")
	}
}

func verifyRefundTransfer(cur realm, creatorGnsBefore int64) {
	// Reward token is GNS; the deposit GNS is also returned to the refundee.
	// The creator receives exactly refund + depositGns. The refund portion is
	// the union of all unclaimable gaps (18 days at 1000/sec here) and is
	// verified precisely from the balance delta.
	gnsAfter := gns.BalanceOf(externalCreatorUser)
	delta := gnsAfter - creatorGnsBefore
	refund := delta - depositGnsAmount

	lower := EXPECTED_REFUND - REFUND_TOLERANCE
	upper := EXPECTED_REFUND + REFUND_TOLERANCE
	inRange := refund >= lower && refund <= upper

	ufmt.Printf("[INFO] creator GNS balance delta after end: %d\n", delta)
	ufmt.Printf("[INFO] refunded reward (excl. GNS deposit): %d\n", refund)
	ufmt.Printf("[RESULT] refund covers union of all unclaimable gaps: %t (%d within [%d, %d])\n", inRange, refund, lower, upper)

	if !inRange {
		panic("refunded reward tokens do not cover the union of all unclaimable gaps")
	}
}

func collectExternalIncentive(cur realm) {
	testing.SetRealm(userRealm)

	// The unstakes above settled their rewards into the claimable ledger without paying
	// them out. Flush that first so the delta below measures only this collection.
	sr.ClaimRewards(cross(cur))

	gnsBefore := gns.BalanceOf(userUser)
	sr.CollectReward(cross(cur), 1)
	gnsAfter := gns.BalanceOf(userUser)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] user collected %d GNS after incentive end\n", rewards)

	if rewards <= 0 {
		panic("expected a positive collect for the staked position after incentive end")
	}
}

func positionIdFrom(cur realm, positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] External incentive refund executes with multiple unclaimable periods
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] created pool and set tier
//
// [SCENARIO] 3. Create external incentive and stake at start
// [INFO] created external incentive g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5:1234567900:1
//
// [SCENARIO] 4. Run stake/unstake cycles to build unclaimable gaps
// [INFO] user staked position 1 at incentive start
// [INFO] unstaked after 864000 seconds (gap 864000 starts)
// [INFO] restaked (gap 864000 ends)
// [INFO] unstaked after 432000 seconds (gap 432000 starts)
// [INFO] restaked (gap 432000 ends)
// [INFO] unstaked after 432000 seconds (gap 259200 starts)
// [INFO] restaked (gap 259200 ends)
// [INFO] position stays staked for the final 4492800 seconds
//
// [SCENARIO] 5. Skip until after incentive end (no collect)
// [INFO] skipped to after incentive end without collecting
//
// [SCENARIO] 6. Creator ends incentive (refund path)
// [INFO] external incentive ended via refund path
//
// [SCENARIO] 7. Verify refund accounts for ALL unclaimable periods
// [INFO] TotalRewardAmount: 7776000000
// [INFO] RemainingRewardAmount: 4492795004
// [INFO] DistributedRewardAmount: 2160004996
// [INFO] AccumulatedPenaltyAmount: 1123200000
// [RESULT] remaining+distributed+penalty == total: true (7776000000 == 7776000000)
// [RESULT] distributed >= union of all unclaimable gaps: true (2160004996 >= 1555080000)
//
// [SCENARIO] 8. Creator received the refunded reward tokens
// [INFO] creator GNS balance delta after end: 101555205000
// [INFO] refunded reward (excl. GNS deposit): 1555205000
// [RESULT] refund covers union of all unclaimable gaps: true (1555205000 within [1555080000, 1555320000])
//
// [SCENARIO] 9. Staked user still collects their legitimate share
// [INFO] user collected 2980794998 GNS after incentive end
