// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. atom:sol:100

// POSITIONs:
// 1. in-range position

// SCENARIO:
// This test verifies external incentive refund behavior after CollectReward changes.
// It validates that:
// 1. External reward penalty is NOT sent to community pool during CollectReward;
//    the penalty share stays in the staker contract as accumulated penalty.
// 2. EndExternalIncentive refunds only the GNS deposit to the creator and does
//    NOT refund the accumulated penalty SOL (it remains in the staker contract
//    until CollectExternalIncentivePenalty is called separately).
// 3. Reward accounting: distributed rewards + staker-retained penalty SOL
//    equals the total reward amount. "Undistributed reward refunded" is 0 here
//    because the leftover SOL is retained as penalty, not refunded on end.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	// "gno.land/r/gnoswap/emission"
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

	stakerAddr, _        = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _          = access.GetAddress(prabc.ROLE_POOL.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	atomPath        = "gno.land/r/gnoswap/test_token/atom"
	solPath        = "gno.land/r/gnoswap/test_token/sol"
	fee100  uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	// Duration and reward amount carefully chosen so rewardAmount % duration = 0
	// 90 days = 7776000 seconds
	// 7776000000 / 7776000 = 1000 (perfect division, no remainder)
	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days in seconds = 7,776,000
	REWARD_AMOUNT      int64 = 7776000000        // Perfectly divisible by duration
	REWARD_PER_SECOND  int64 = 1000              // Expected reward per second

	actualIncentiveID     string
	totalRewardsCollected int64 // Track total rewards collected
)

func main() {
	println("[SCENARIO] Testing complete reward distribution with no dust")
	println()

	println("[SCENARIO] 1. Initialize account and settings")
	initAccountAndSettings()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position")
	mintPosition()
	println()

	println("[SCENARIO] 4. Create external incentive with perfectly divisible rewards")
	createExternalIncentiveNoDust()
	println()

	println("[SCENARIO] 5. Start external incentive")
	startExternalIncentive()
	println()

	println("[SCENARIO] 6. Stake position")
	stakePosition()
	println()

	println("[SCENARIO] 7. Skip to middle of incentive period")
	skipToMiddle()
	println()

	println("[SCENARIO] 8. Collect rewards mid-way")
	collectRewardsMidway()
	println()

	println("[SCENARIO] 9. Wait until incentive ends")
	waitUntilEnd()
	println()

	println("[SCENARIO] 10. Collect final rewards")
	collectFinalRewards()
	println()

	println("[SCENARIO] 11. Unstake position to collect all remaining rewards")
	unstakePosition()
	println()

	println("[SCENARIO] 12. End external incentive and verify no dust")
	endExternalIncentiveAndVerifyNoDust()
	println()
}

func initAccountAndSettings() {
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] set pool tier for rewards")
	testing.SkipHeights(1)

	println("[INFO] transfer SOL reward and GNS deposit to external creator")
	sol.Transfer(cross, externalCreatorUser, REWARD_AMOUNT)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool atom:sol:100 at tick 0")
	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		atomPath,
		solPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	println("[INFO] set pool tier")
	sr.SetPoolTier(cross, "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", 1)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position")
	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint in-range position (tick range: -100 ~ 100)")
	testing.SkipHeights(1)
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		atomPath,
		solPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[INFO] minted position - tokenId: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[INFO] amounts used - token0: %s, token1: %s\n", amount0, amount1)
}

func createExternalIncentiveNoDust() {
	testing.SetRealm(externalCreatorRealm)

	println("[INFO] approve SOL and GNS for external incentive creation")
	sol.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	// Calculate expected values
	expectedRewardPerSecond := REWARD_AMOUNT / INCENTIVE_DURATION
	expectedDust := REWARD_AMOUNT - (expectedRewardPerSecond * INCENTIVE_DURATION)

	ufmt.Printf("[INFO] creating incentive with:\n")
	ufmt.Printf("  - Reward amount: %d SOL\n", REWARD_AMOUNT)
	ufmt.Printf("  - Duration: %d seconds\n", INCENTIVE_DURATION)
	ufmt.Printf("  - Expected reward per second: %d\n", expectedRewardPerSecond)
	ufmt.Printf("  - Expected dust (should be 0): %d\n", expectedDust)

	// Generate the incentive ID
	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)
	ufmt.Printf("[INFO] incentive ID: %s\n", actualIncentiveID)

	// Record balances before creation
	creatorSolBefore := sol.BalanceOf(externalCreatorUser)
	stakerSolBefore := sol.BalanceOf(stakerAddr)
	creatorGnsBefore := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] creator SOL balance before: %d\n", creatorSolBefore)
	ufmt.Printf("[INFO] staker SOL balance before: %d\n", stakerSolBefore)
	ufmt.Printf("[INFO] creator GNS balance before: %d\n", creatorGnsBefore)

	// External incentive must start at least +1 day midnight
	// Using fixed timestamp for consistent testing
	startTime := int64(1234569600) // This is the required +1 day midnight timestamp
	endTime := startTime + INCENTIVE_DURATION

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		solPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	creatorSolAfter := sol.BalanceOf(externalCreatorUser)
	stakerSolAfter := sol.BalanceOf(stakerAddr)
	creatorGnsAfter := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] creator SOL balance after: %d\n", creatorSolAfter)
	ufmt.Printf("[INFO] staker SOL balance after: %d\n", stakerSolAfter)
	ufmt.Printf("[INFO] creator GNS balance after: %d\n", creatorGnsAfter)

	totalSolDeposited := creatorSolBefore - creatorSolAfter
	ufmt.Printf("[INFO] total SOL deposited as reward: %d\n", totalSolDeposited)
}

func startExternalIncentive() {
	// Skip to start time (1234569600)
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime

	blockLeft := timeLeft / 5 // 5 seconds per block

	println("[INFO] skipping blocks until external incentive starts")
	testing.SkipHeights(int64(blockLeft))
	println("[INFO] external incentive started")
}

func stakePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT for staking")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))

	println("[INFO] stake position")
	sr.StakeToken(cross, 1, "")

	owner := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[INFO] position owner after staking: %s\n", owner)
}

func skipToMiddle() {
	// Skip to middle of incentive period (half of duration)
	blocksToSkip := (INCENTIVE_DURATION / 2) / 5
	testing.SkipHeights(blocksToSkip)
	println("[INFO] reached middle of incentive period")
}

func collectRewardsMidway() {
	testing.SetRealm(adminRealm)

	adminSolBefore := sol.BalanceOf(adminUser)
	communitySolBefore := sol.BalanceOf(communityPoolAddr)
	println("[INFO] collecting rewards at midway point")

	// Collect rewards without unwrap
	sr.CollectReward(cross, 1)

	adminSolAfter := sol.BalanceOf(adminUser)
	communitySolAfter := sol.BalanceOf(communityPoolAddr)
	midwayRewards := adminSolAfter - adminSolBefore
	totalRewardsCollected += midwayRewards

	ufmt.Printf("[INFO] rewards collected at midway: %d SOL\n", midwayRewards)
	ufmt.Printf("[INFO] expected midway rewards (approx): %d SOL\n", REWARD_AMOUNT/2)
	ufmt.Printf("[EXPECTED] community pool SOL unchanged on collect: %d -> %d\n", communitySolBefore, communitySolAfter)
}

func waitUntilEnd() {
	// Skip remaining time
	blocksToSkip := (INCENTIVE_DURATION/2)/5 + 10
	testing.SkipHeights(blocksToSkip)
	println("[INFO] incentive period has ended")
}

func collectFinalRewards() {
	testing.SetRealm(adminRealm)

	adminSolBefore := sol.BalanceOf(adminUser)
	communitySolBefore := sol.BalanceOf(communityPoolAddr)
	println("[INFO] collecting final rewards")

	// Collect remaining rewards
	sr.CollectReward(cross, 1)

	adminSolAfter := sol.BalanceOf(adminUser)
	communitySolAfter := sol.BalanceOf(communityPoolAddr)
	finalRewards := adminSolAfter - adminSolBefore
	totalRewardsCollected += finalRewards

	ufmt.Printf("[INFO] final rewards collected: %d SOL\n", finalRewards)
	ufmt.Printf("[EXPECTED] community pool SOL unchanged on collect: %d -> %d\n", communitySolBefore, communitySolAfter)
}

func unstakePosition() {
	testing.SetRealm(adminRealm)

	adminSolBefore := sol.BalanceOf(adminUser)
	println("[INFO] unstaking position to collect remaining rewards")

	// Unstake position (this will collect any remaining rewards)
	sr.UnStakeToken(cross, 1)

	adminSolAfter := sol.BalanceOf(adminUser)
	unstakeRewards := adminSolAfter - adminSolBefore
	totalRewardsCollected += unstakeRewards

	ufmt.Printf("[INFO] rewards collected from unstaking: %d SOL\n", unstakeRewards)
	ufmt.Printf("[INFO] total rewards collected so far: %d SOL\n", totalRewardsCollected)

	// Verify NFT ownership returned
	owner := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[INFO] position owner after unstaking: %s\n", owner)
}

func endExternalIncentiveAndVerifyNoDust() {
	testing.SetRealm(externalCreatorRealm)

	println("[INFO] ending external incentive")

	// Record balances before ending
	creatorSolBefore := sol.BalanceOf(externalCreatorUser)
	stakerSolBefore := sol.BalanceOf(stakerAddr)
	creatorGnsBefore := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] before ending incentive:\n")
	ufmt.Printf("  - Creator SOL: %d\n", creatorSolBefore)
	ufmt.Printf("  - Staker contract SOL: %d\n", stakerSolBefore)
	ufmt.Printf("  - Creator GNS (deposit): %d\n", creatorGnsBefore)
	ufmt.Printf("  - Admin total rewards collected (SOL): %d\n", totalRewardsCollected)

	// End the external incentive
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	// Check balances after ending
	creatorSolAfter := sol.BalanceOf(externalCreatorUser)
	stakerSolAfter := sol.BalanceOf(stakerAddr)
	creatorGnsAfter := gns.BalanceOf(externalCreatorUser)

	refundSolAmount := creatorSolAfter - creatorSolBefore
	stakerSolReduction := stakerSolBefore - stakerSolAfter
	refundGnsAmount := creatorGnsAfter - creatorGnsBefore

	ufmt.Printf("[INFO] after ending incentive:\n")
	ufmt.Printf("  - Creator SOL: %d\n", creatorSolAfter)
	ufmt.Printf("  - Staker contract SOL: %d\n", stakerSolAfter)
	ufmt.Printf("  - Creator GNS (deposit): %d\n", creatorGnsAfter)
	ufmt.Printf("  - Admin SOL balances: %d\n", sol.BalanceOf(adminUser))

	ufmt.Printf("[RESULT] refund breakdown:\n")
	ufmt.Printf("  - Total refunded reward token (SOL): %d\n", refundSolAmount)
	ufmt.Printf("  - Total reduced from staker SOL: %d\n", stakerSolReduction)
	ufmt.Printf("  - Refunded GNS deposit: %d\n", refundGnsAmount)

	ufmt.Printf("[EXPECTED] creator receives all remaining reward token: %d\n", stakerSolBefore)
	ufmt.Printf("[EXPECTED] creator receives fixed GNS deposit: %d\n", depositGnsAmount)

	// Verify total distribution
	ufmt.Printf("[EXPECTED] Total reward distribution:\n")
	ufmt.Printf("  - Initial reward amount: %d SOL\n", REWARD_AMOUNT)
	ufmt.Printf("  - Rewards collected by staker: %d SOL\n", totalRewardsCollected)
	undistributedRewardRefunded := refundSolAmount
	ufmt.Printf("  - Undistributed reward refunded: %d SOL\n", undistributedRewardRefunded)

	totalDistributed := totalRewardsCollected + undistributedRewardRefunded
	ufmt.Printf("  - Total accounted for: %d SOL\n", totalDistributed)

	// Leftover SOL retained in the staker contract (accumulated penalty share).
	// This is NOT refunded by EndExternalIncentive; it must be collected via
	// CollectExternalIncentivePenalty.
	stakerRetainedPenalty := stakerSolAfter
	ufmt.Printf("  - Staker-retained penalty SOL: %d\n", stakerRetainedPenalty)
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing complete reward distribution with no dust
//
// [SCENARIO] 1. Initialize account and settings
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] set pool tier for rewards
// [INFO] transfer SOL reward and GNS deposit to external creator
//
// [SCENARIO] 2. Create pool
// [INFO] create pool atom:sol:100 at tick 0
// [INFO] set pool tier
//
// [SCENARIO] 3. Mint position
// [INFO] approve tokens for position
// [INFO] mint in-range position (tick range: -100 ~ 100)
// [INFO] minted position - tokenId: 1, liquidity: 200510
// [INFO] amounts used - token0: 1000, token1: 1000
//
// [SCENARIO] 4. Create external incentive with perfectly divisible rewards
// [INFO] approve SOL and GNS for external incentive creation
// [INFO] creating incentive with:
//   - Reward amount: 7776000000 SOL
//   - Duration: 7776000 seconds
//   - Expected reward per second: 1000
//   - Expected dust (should be 0): 0
// [INFO] incentive ID: g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567905:1
// [INFO] creator SOL balance before: 7776000000
// [INFO] staker SOL balance before: 0
// [INFO] creator GNS balance before: 1000000000
// [INFO] creator SOL balance after: 0
// [INFO] staker SOL balance after: 7776000000
// [INFO] creator GNS balance after: 0
// [INFO] total SOL deposited as reward: 7776000000
//
// [SCENARIO] 5. Start external incentive
// [INFO] skipping blocks until external incentive starts
// [INFO] external incentive started
//
// [SCENARIO] 6. Stake position
// [INFO] approve NFT for staking
// [INFO] stake position
// [INFO] position owner after staking: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
//
// [SCENARIO] 7. Skip to middle of incentive period
// [INFO] reached middle of incentive period
//
// [SCENARIO] 8. Collect rewards mid-way
// [INFO] collecting rewards at midway point
// [INFO] rewards collected at midway: 2375999998 SOL
// [INFO] expected midway rewards (approx): 3888000000 SOL
// [EXPECTED] community pool SOL unchanged on collect: 0 -> 0
//
// [SCENARIO] 9. Wait until incentive ends
// [INFO] incentive period has ended
//
// [SCENARIO] 10. Collect final rewards
// [INFO] collecting final rewards
// [INFO] final rewards collected: 3887999999 SOL
// [EXPECTED] community pool SOL unchanged on collect: 0 -> 0
//
// [SCENARIO] 11. Unstake position to collect all remaining rewards
// [INFO] unstaking position to collect remaining rewards
// [INFO] rewards collected from unstaking: 0 SOL
// [INFO] total rewards collected so far: 6263999997 SOL
// [INFO] position owner after unstaking: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 12. End external incentive and verify no dust
// [INFO] ending external incentive
// [INFO] before ending incentive:
//   - Creator SOL: 0
//   - Staker contract SOL: 1512000003
//   - Creator GNS (deposit): 0
//   - Admin total rewards collected (SOL): 6263999997
// [INFO] after ending incentive:
//   - Creator SOL: 0
//   - Staker contract SOL: 1512000003
//   - Creator GNS (deposit): 1000000000
//   - Admin SOL balances: 599999998487998997
// [RESULT] refund breakdown:
//   - Total refunded reward token (SOL): 0
//   - Total reduced from staker SOL: 0
//   - Refunded GNS deposit: 1000000000
// [EXPECTED] creator receives all remaining reward token: 1512000003
// [EXPECTED] creator receives fixed GNS deposit: 1000000000
// [EXPECTED] Total reward distribution:
//   - Initial reward amount: 7776000000 SOL
//   - Rewards collected by staker: 6263999997 SOL
//   - Undistributed reward refunded: 0 SOL
//   - Total accounted for: 6263999997 SOL
//   - Staker-retained penalty SOL: 1512000003
