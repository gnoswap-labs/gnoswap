// PKGPATH: gno.land/r/gnoswap/v1/main

// SCENARIO:
// Tests CollectExternalIncentivePenalty function:
// 1. Create pool and external incentive (SOL reward, 90 days)
// 2. Stake position and collect rewards multiple times (accumulates warmup penalty)
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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
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

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	solPath = "gno.land/r/gnoswap/test_token/sol"
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

	println("[SCENARIO] 9. Verify new penalty accrues and can be collected again")
	collectPenaltyAgain()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	// transfer SOL to external creator for incentive
	sol.Transfer(cross, externalCreatorUser, REWARD_AMOUNT)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	// transfer tokens to admin for position
	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	println("[INFO] initialized accounts")
}

func createPool() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	pl.CreatePool(
		cross,
		atomPath,
		solPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	sr.SetPoolTier(cross, "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", 1)
	println("[INFO] created pool and set tier")
}

func createExternalIncentive() {
	testing.SetRealm(externalCreatorRealm)
	sol.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()
	startTime := int64(1234569600) // Fixed start time
	endTime := startTime + INCENTIVE_DURATION
	incentiveStartTime = startTime
	incentiveEndTime = endTime

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, createTimestamp, 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		solPath,
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
		atomPath,
		solPath,
		fee100,
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
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

	penaltyAfterCollect := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", actualIncentiveID)
	distributedAfterCollect := sr.GetIncentiveDistributedRewardAmount("gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", actualIncentiveID)

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
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	println("[INFO] external incentive ended")
}

func collectPenalty() {
	creatorSolBefore := sol.BalanceOf(externalCreatorUser)
	penaltyBefore := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", actualIncentiveID)

	testing.SetRealm(externalCreatorRealm)
	collected := sr.CollectExternalIncentivePenalty(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	creatorSolAfter := sol.BalanceOf(externalCreatorUser)
	penaltyAfter := sr.GetIncentiveAccumulatedPenaltyAmount("gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", actualIncentiveID)

	ufmt.Printf("[INFO] penalty before collection: %d\n", penaltyBefore)
	ufmt.Printf("[INFO] penalty collected: %d\n", collected)
	ufmt.Printf("[INFO] penalty remaining: %d\n", penaltyAfter)
	ufmt.Printf("[INFO] creator SOL before: %d\n", creatorSolBefore)
	ufmt.Printf("[INFO] creator SOL after: %d\n", creatorSolAfter)
	ufmt.Printf("[INFO] creator SOL increase: %d\n", creatorSolAfter-creatorSolBefore)

	if collected > 0 {
		println("[EXPECTED] penalty successfully collected to creator")
	}

	if penaltyAfter == 0 {
		println("[EXPECTED] accumulatedPenaltyAmount reset to 0")
	}

	ufmt.Printf("[EXPECTED] staker gns balance: %d\n", gns.BalanceOf(stakerAddr))
	ufmt.Printf("[EXPECTED] staker sol balance: %d\n", sol.BalanceOf(stakerAddr))
}

func collectPenaltyAgain() {
	testing.SkipHeights(1)
	testing.SetRealm(externalCreatorRealm)
	collected := sr.CollectExternalIncentivePenalty(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	ufmt.Printf("[INFO] second collection returned: %d\n", collected)

	if collected > 0 {
		println("[EXPECTED] new penalty accrued after later CollectReward is collected again")
	}

	ufmt.Printf("[EXPECTED] staker gns balance: %d\n", gns.BalanceOf(stakerAddr))
	ufmt.Printf("[EXPECTED] staker sol balance: %d\n", sol.BalanceOf(stakerAddr))
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
// [INFO] creator SOL before: 3173785
// [INFO] creator SOL after: 1302716185
// [INFO] creator SOL increase: 1299542400
// [EXPECTED] penalty successfully collected to creator
// [EXPECTED] accumulatedPenaltyAmount reset to 0
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker sol balance: 5997882216
//
// [SCENARIO] 8. Collect reward after external incentive ends
// [INFO] after CollectReward:
//   - accumulatedPenaltyAmount: 449841600
//   - distributedRewardAmount: 7250615998
// [EXPECTED] penalty accumulated during CollectReward
//
// [SCENARIO] 9. Verify new penalty accrues and can be collected again
// [INFO] second collection returned: 449841600
// [EXPECTED] new penalty accrued after later CollectReward is collected again
// [EXPECTED] staker gns balance: 0
// [EXPECTED] staker sol balance: 2
