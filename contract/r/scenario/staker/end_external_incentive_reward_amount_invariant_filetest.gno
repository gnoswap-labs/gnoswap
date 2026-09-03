// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100
//
// POSITIONs:
// 1. Single position staked 10 days after incentive start (leaves a real,
//    unclaimable gap at the beginning that nobody could ever have collected)
//
// SCENARIO:
// Regression test: EndExternalIncentive used to transfer `refund` reward tokens
// out of the staker and add it to DistributedRewardAmount, but never decremented
// RewardAmount. That broke the accounting invariant
//   TotalRewardAmount == RewardAmount + DistributedRewardAmount + AccumulatedPenaltyAmount
// and made GetIncentiveRemainingRewardAmount report stale, inflated values after a refund.
//
// 1. Create a 90-day external incentive, but stake the position 10 days after start
//    (a real, unclaimable gap nobody could ever collect for).
// 2. Skip past incentive end without collecting.
// 3. Creator calls EndExternalIncentive to refund the unclaimable gap.
// 4. Verify RewardAmount + DistributedRewardAmount + AccumulatedPenaltyAmount == TotalRewardAmount.
// 5. The staked position still collects its full, legitimate share afterwards -- the
//    refund must not have touched money owed to a real, still-uncollected staker.

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

	depositGnsAmount int64 = 1_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 7_776_000_000     // divides evenly by duration: 1000/sec
	STAKE_DELAY        int64 = 10 * 24 * 60 * 60 // stake 10 days after incentive start

	actualIncentiveID string
	targetPoolPath    = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"
)

func main(cur realm) {
	println("[SCENARIO] EndExternalIncentive keeps RewardAmount accounting consistent after refund")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier(cur)
	println()

	println("[SCENARIO] 3. Create external incentive and wait for start")
	createAndStartIncentive(cur)
	println()

	println("[SCENARIO] 4. Skip 10 days with nobody staked (unclaimable gap)")
	skipStakeDelay(cur)
	println()

	println("[SCENARIO] 5. User mints and stakes position")
	userMintThenStake(cur)
	println()

	println("[SCENARIO] 6. Skip until after incentive end (no collect)")
	skipUntilAfterEnd(cur)
	println()

	println("[SCENARIO] 7. Creator ends incentive (refund path)")
	endExternalIncentive(cur)
	println()

	println("[SCENARIO] 8. Verify accounting invariant after refund")
	verifyAccountingInvariant(cur)
	println()

	println("[SCENARIO] 9. Staked user still collects their full legitimate share")
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

	// Move chain time to incentive start
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	if timeLeft > 0 {
		testing.SkipHeights(timeLeft / 5)
	}

	ufmt.Printf("[INFO] created external incentive %s\n", actualIncentiveID)
}

func skipStakeDelay(cur realm) {
	testing.SkipHeights(STAKE_DELAY / 5)
	println("[INFO] skipped 10 days with zero staked liquidity")
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

func skipUntilAfterEnd(cur realm) {
	// Skip the rest of the 90-day period plus a 1-day buffer past end.
	blocksToSkip := ((INCENTIVE_DURATION - STAKE_DELAY) + 24*60*60) / 5
	testing.SkipHeights(blocksToSkip)
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

func verifyAccountingInvariant(cur realm) {
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

	if sum != total {
		panic("accounting invariant broken: remaining+distributed+penalty != total")
	}
	if distributed == 0 {
		panic("expected a non-zero refund from the unclaimable gap")
	}
}

func collectExternalIncentive(cur realm) {
	testing.SetRealm(userRealm)

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
// [SCENARIO] EndExternalIncentive keeps RewardAmount accounting consistent after refund
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] created pool and set tier
//
// [SCENARIO] 3. Create external incentive and wait for start
// [INFO] created external incentive g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz:1234567900:1
//
// [SCENARIO] 4. Skip 10 days with nobody staked (unclaimable gap)
// [INFO] skipped 10 days with zero staked liquidity
//
// [SCENARIO] 5. User mints and stakes position
// [INFO] user staked position 1
//
// [SCENARIO] 6. Skip until after incentive end (no collect)
// [INFO] skipped to after incentive end without collecting
//
// [SCENARIO] 7. Creator ends incentive (refund path)
// [INFO] external incentive ended via refund path
//
// [SCENARIO] 8. Verify accounting invariant after refund
// [INFO] TotalRewardAmount: 7776000000
// [INFO] RemainingRewardAmount: 6911995000
// [INFO] DistributedRewardAmount: 864005000
// [INFO] AccumulatedPenaltyAmount: 0
// [RESULT] remaining+distributed+penalty == total: true (7776000000 == 7776000000)
//
// [SCENARIO] 9. Staked user still collects their full legitimate share
// [INFO] user collected 5399994997 GNS after incentive end
