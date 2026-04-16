// PKGPATH: gno.land/r/gnoswap/v1/main

// SCENARIO:
// Tests CollectExternalIncentivePenalty function:
// 1. Create pool and external incentive (QUX reward, 90 days)
// 2. Stake position and collect rewards multiple times (accumulates warmup penalty)
// 3. End external incentive
// 4. Admin collects accumulated penalty → community pool
// 5. Verify penalty is transferred and accumulatedPenaltyAmount is reset

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
	startAndStake()
	println()

	println("[SCENARIO] 5. Collect rewards (accumulates penalty)")
	collectRewards()
	println()

	println("[SCENARIO] 6. End external incentive")
	endIncentive()
	println()

	println("[SCENARIO] 7. Collect penalty")
	collectPenalty()
	println()

	println("[SCENARIO] 8. Collect reward after external incentive ends")
	collectRewards()
	println()

	println("[SCENARIO] 9. Verify second penalty collection")
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

func startAndStake() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	pn.Mint(
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
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	println("[INFO] staked position 1")
}

func collectRewards() {
	// skip 30 days to accumulate rewards (still in warmup)
	testing.SkipHeights(30 * 24 * 60 * 60 / 5)

	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 1)

	penaltyAfterCollect := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)
	distributedAfterCollect := sr.GetIncentiveDistributedRewardAmount("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", actualIncentiveID)

	ufmt.Printf("[INFO] after CollectReward:\n")
	ufmt.Printf("  - accumulatedPenaltyAmount: %d\n", penaltyAfterCollect)
	ufmt.Printf("  - distributedRewardAmount: %d\n", distributedAfterCollect)

	if penaltyAfterCollect > 0 {
		println("[EXPECTED] penalty accumulated during CollectReward")
	} else {
		println("[WARNING] no penalty accumulated — warmup may not be active")
	}
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

	if collected == 0 {
		println("[EXPECTED] second collection returns 0 (no more penalty)")
	}

	ufmt.Printf("[EXPECTED] staker gns balance: %d\n", gns.BalanceOf(stakerAddr))
	ufmt.Printf("[EXPECTED] staker qux balance: %d\n", qux.BalanceOf(stakerAddr))
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
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
// [INFO] staked position 1
//
// [SCENARIO] 5. Collect rewards (accumulates penalty)
// [INFO] after CollectReward:
//   - accumulatedPenaltyAmount: 1299542400
//   - distributedRewardAmount: 1699401599
// [EXPECTED] penalty accumulated during CollectReward
//
// [SCENARIO] 6. End external incentive
// [INFO] external incentive ended
//
// [SCENARIO] 7. Collect penalty
// [INFO] penalty before collection: 1299542400
// [INFO] penalty collected: 1299542400
// [INFO] penalty remaining: 0
// [INFO] creator QUX before: 3173785
// [INFO] creator QUX after: 1302716185
// [INFO] creator QUX increase: 1299542400
// [EXPECTED] penalty successfully collected to creator
// [EXPECTED] accumulatedPenaltyAmount reset to 0
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker qux balance: 5997882216
//
// [SCENARIO] 8. Collect reward after external incentive ends
// [INFO] after CollectReward:
//   - accumulatedPenaltyAmount: 449841600
//   - distributedRewardAmount: 7250615998
// [EXPECTED] penalty accumulated during CollectReward
//
// [SCENARIO] 9. Verify second penalty collection
// [INFO] second collection returned: 449841600
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker qux balance: 2
