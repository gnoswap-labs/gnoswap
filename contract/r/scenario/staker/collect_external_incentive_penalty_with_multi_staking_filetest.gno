// PKGPATH: gno.land/r/gnoswap/v1/main

// SCENARIO:
// Tests CollectExternalIncentivePenalty function with multiple staked positions:
// 1. Create pool and external incentive (QUX reward, 90 days)
// 2. Stake multiple positions and collect rewards (accumulates warmup penalty)
// 3. End external incentive
// 4. External creator collects accumulated penalty → refunded to creator
// 5. Verify penalty is transferred and accumulatedPenaltyAmount is reset
// 6. Further CollectReward calls accrue new penalty, which a subsequent
//    CollectExternalIncentivePenalty call can collect again

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
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

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = testing.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 1_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 9_000_000_000

	actualIncentiveID  string
	incentiveStartTime int64
	incentiveEndTime   int64
)

func main() {
	println("[SCENARIO] CollectExternalIncentivePenalty")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Create external incentive")
	createExternalIncentive()
	println()

	println("[SCENARIO] 4. Start incentive and stake position")
	testing.SkipHeights(1)
	stakePosition()
	stakePosition()
	stakePosition()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Collect rewards (accumulates penalty)")
	// skip 30 days to accumulate rewards (still in warmup)
	testing.SkipHeights(30 * 24 * 60 * 60 / 5)
	collectRewards(1)
	collectRewards(2)
	println()

	println("[SCENARIO] 6. End external incentive")
	endIncentive()
	println()

	println("[SCENARIO] 7. Collect penalty")
	testing.SkipHeights(1)
	collectPenalty()
	println()

	println("[SCENARIO] 8. Collect reward after external incentive ends")
	testing.SkipHeights(1)
	collectRewards(1)
	testing.SkipHeights(1)
	collectRewards(2)
	testing.SkipHeights(1)
	collectRewards(3)
	println()

	println("[SCENARIO] 9. Verify new penalty accrues and can be collected again")
	collectPenaltyAgain()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	// transfer QUX to external creator for incentive
	qux.Transfer(cross, externalCreatorUser, REWARD_AMOUNT)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	// transfer tokens to admin for position
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] initialized accounts")
}

func createPool() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)
	println("[INFO] created pool and set tier")
}

func createExternalIncentive() {
	testing.SetRealm(externalCreatorRealm)
	qux.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTime := int64(1234569600) // Fixed start time
	endTime := startTime + INCENTIVE_DURATION
	incentiveStartTime = startTime
	incentiveEndTime = endTime

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, createTimestamp, 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		quxPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// skip to incentive start
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	if timeLeft > 0 {
		blocksToSkip := timeLeft / 5
		testing.SkipHeights(blocksToSkip)
	}

	ufmt.Printf("[INFO] created external incentive: %s\n", actualIncentiveID)
}

func stakePosition() {
	testing.SetRealm(adminRealm)

	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr.String(),
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	ufmt.Printf("[INFO] staked position %d (liquidity: %s)\n", positionId, liquidity)
}

func collectRewards(positionId uint64) {
	testing.SetRealm(adminRealm)
	quxBeforeCollect := qux.BalanceOf(adminAddr)
	sr.CollectReward(cross, positionId)

	penaltyAfterCollect := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)
	distributedAfterCollect := sr.GetIncentiveDistributedRewardAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)
	quxAfterCollect := qux.BalanceOf(adminAddr)
	quxCollected := quxAfterCollect - quxBeforeCollect

	ufmt.Printf("[INFO] position %d CollectReward:\n", positionId)
	ufmt.Printf("  - accumulatedPenaltyAmount: %d\n", penaltyAfterCollect)
	ufmt.Printf("  - distributedRewardAmount: %d\n", distributedAfterCollect)
	ufmt.Printf("  - qux collected: %d\n", quxCollected)
}

func endIncentive() {
	nowTime := time.Now().Unix()
	timeLeft := incentiveEndTime - nowTime
	testing.SkipHeights(timeLeft / 5)

	testing.SetRealm(externalCreatorRealm)
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	println("[INFO] external incentive ended")
}

func collectPenalty() {
	creatorQuxBefore := qux.BalanceOf(externalCreatorUser)
	penaltyBefore := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)

	testing.SetRealm(externalCreatorRealm)
	collected := sr.CollectExternalIncentivePenalty(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	creatorQuxAfter := qux.BalanceOf(externalCreatorUser)
	penaltyAfter := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)

	ufmt.Printf("[INFO] penalty before collection: %d\n", penaltyBefore)
	ufmt.Printf("[INFO] penalty collected: %d\n", collected)
	ufmt.Printf("[INFO] penalty remaining: %d\n", penaltyAfter)
	ufmt.Printf("[INFO] creator QUX before: %d\n", creatorQuxBefore)
	ufmt.Printf("[INFO] creator QUX after: %d\n", creatorQuxAfter)
	ufmt.Printf("[INFO] creator QUX increase: %d\n", creatorQuxAfter-creatorQuxBefore)

	if collected > 0 {
		println("[EXPECTED] penalty successfully collected to creator")
	}

	if penaltyAfter == 0 {
		println("[EXPECTED] accumulatedPenaltyAmount reset to 0")
	}

	ufmt.Printf("[EXPECTED] staker gns balance: %d\n", gns.BalanceOf(stakerAddr))
	ufmt.Printf("[EXPECTED] staker qux balance: %d\n", qux.BalanceOf(stakerAddr))
}

func collectPenaltyAgain() {
	testing.SkipHeights(1)
	testing.SetRealm(externalCreatorRealm)
	collected := sr.CollectExternalIncentivePenalty(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	ufmt.Printf("[INFO] second collection returned: %d\n", collected)

	if collected > 0 {
		println("[EXPECTED] new penalty accrued after later CollectReward is collected again")
	}

	ufmt.Printf("[EXPECTED] staker gns balance: %d\n", gns.BalanceOf(stakerAddr))
	ufmt.Printf("[EXPECTED] staker qux balance: %d\n", qux.BalanceOf(stakerAddr))
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(positionId, 10))
}

// Output:
// [SCENARIO] CollectExternalIncentivePenalty
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool
// [INFO] created pool and set tier
//
// [SCENARIO] 3. Create external incentive
// [INFO] created external incentive: g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567900:1
//
// [SCENARIO] 4. Start incentive and stake position
// [INFO] staked position 1 (liquidity: 20026)
// [INFO] staked position 2 (liquidity: 20026)
// [INFO] staked position 3 (liquidity: 20026)
//
// [SCENARIO] 5. Collect rewards (accumulates penalty)
// [INFO] position 1 CollectReward:
//   - accumulatedPenaltyAmount: 433181379
//   - distributedRewardAmount: 566468547
//   - qux collected: 566468547
// [INFO] position 2 CollectReward:
//   - accumulatedPenaltyAmount: 866362758
//   - distributedRewardAmount: 1132937094
//   - qux collected: 566468547
//
// [SCENARIO] 6. End external incentive
// [INFO] external incentive ended
//
// [SCENARIO] 7. Collect penalty
// [INFO] penalty before collection: 866362758
// [INFO] penalty collected: 866362758
// [INFO] penalty remaining: 0
// [INFO] creator QUX before: 3173785
// [INFO] creator QUX after: 869536543
// [INFO] creator QUX increase: 866362758
// [EXPECTED] penalty successfully collected to creator
// [EXPECTED] accumulatedPenaltyAmount reset to 0
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker qux balance: 6997526363
//
// [SCENARIO] 8. Collect reward after external incentive ends
// [INFO] position 1 CollectReward:
//   - accumulatedPenaltyAmount: 149946622
//   - distributedRewardAmount: 2985456399
//   - qux collected: 1849345520
// [INFO] position 2 CollectReward:
//   - accumulatedPenaltyAmount: 299893244
//   - distributedRewardAmount: 4834801919
//   - qux collected: 1849345520
// [INFO] position 3 CollectReward:
//   - accumulatedPenaltyAmount: 883021244
//   - distributedRewardAmount: 7250615987
//   - qux collected: 2415814068
//
// [SCENARIO] 9. Verify new penalty accrues and can be collected again
// [INFO] second collection returned: 883021244
// [EXPECTED] new penalty accrued after later CollectReward is collected again
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker qux balance: 11
