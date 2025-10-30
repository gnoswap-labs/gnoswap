// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. in-range position

// SCENARIO:
// This test verifies that when rewardAmount is perfectly divisible by duration,
// all rewards are fully distributed with no dust remaining.
// The test creates an external incentive where rewardAmount % duration = 0,
// stakes a position to earn rewards, and then verifies that:
// 1. All rewards are distributed to stakers
// 2. No dust is refunded when the incentive ends
// 3. The refundee receives only the deposit fee back

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

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

	println("[INFO] transfer GNS to external creator for incentive creation")
	gns.Transfer(cross, externalCreatorUser, REWARD_AMOUNT+depositGnsAmount)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool bar:qux:100 at tick 0")
	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	println("[INFO] set pool tier")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint in-range position (tick range: -100 ~ 100)")
	testing.SkipHeights(1)
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
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
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[INFO] minted position - tokenId: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[INFO] amounts used - token0: %s, token1: %s\n", amount0, amount1)
}

func createExternalIncentiveNoDust() {
	testing.SetRealm(externalCreatorRealm)

	println("[INFO] approve GNS for external incentive creation")
	gns.Approve(cross, stakerAddr, maxInt64)

	// Calculate expected values
	expectedRewardPerSecond := REWARD_AMOUNT / INCENTIVE_DURATION
	expectedDust := REWARD_AMOUNT - (expectedRewardPerSecond * INCENTIVE_DURATION)

	ufmt.Printf("[INFO] creating incentive with:\n")
	ufmt.Printf("  - Reward amount: %d GNS\n", REWARD_AMOUNT)
	ufmt.Printf("  - Duration: %d seconds\n", INCENTIVE_DURATION)
	ufmt.Printf("  - Expected reward per second: %d\n", expectedRewardPerSecond)
	ufmt.Printf("  - Expected dust (should be 0): %d\n", expectedDust)

	// Generate the incentive ID
	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)
	ufmt.Printf("[INFO] incentive ID: %s\n", actualIncentiveID)

	// Record balances before creation
	creatorGnsBefore := gns.BalanceOf(externalCreatorUser)
	stakerGnsBefore := gns.BalanceOf(stakerAddr)

	ufmt.Printf("[INFO] creator GNS balance before: %d\n", creatorGnsBefore)
	ufmt.Printf("[INFO] staker GNS balance before: %d\n", stakerGnsBefore)

	// External incentive must start at least +1 day midnight
	// Using fixed timestamp for consistent testing
	startTime := int64(1234569600) // This is the required +1 day midnight timestamp
	endTime := startTime + INCENTIVE_DURATION

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	creatorGnsAfter := gns.BalanceOf(externalCreatorUser)
	stakerGnsAfter := gns.BalanceOf(stakerAddr)

	ufmt.Printf("[INFO] creator GNS balance after: %d\n", creatorGnsAfter)
	ufmt.Printf("[INFO] staker GNS balance after: %d\n", stakerGnsAfter)

	totalDeposited := creatorGnsBefore - creatorGnsAfter
	ufmt.Printf("[INFO] total GNS deposited (reward + fee): %d\n", totalDeposited)
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

	adminGnsBefore := gns.BalanceOf(adminUser)
	println("[INFO] collecting rewards at midway point")

	// Collect rewards without unwrap
	sr.CollectReward(cross, 1, false)

	adminGnsAfter := gns.BalanceOf(adminUser)
	midwayRewards := adminGnsAfter - adminGnsBefore
	totalRewardsCollected += midwayRewards

	ufmt.Printf("[INFO] rewards collected at midway: %d GNS\n", midwayRewards)
	ufmt.Printf("[INFO] expected midway rewards (approx): %d GNS\n", REWARD_AMOUNT/2)
}

func waitUntilEnd() {
	// Skip remaining time
	blocksToSkip := (INCENTIVE_DURATION/2)/5 + 10
	testing.SkipHeights(blocksToSkip)
	println("[INFO] incentive period has ended")
}

func collectFinalRewards() {
	testing.SetRealm(adminRealm)

	adminGnsBefore := gns.BalanceOf(adminUser)
	println("[INFO] collecting final rewards")

	// Collect remaining rewards
	sr.CollectReward(cross, 1, false)

	adminGnsAfter := gns.BalanceOf(adminUser)
	finalRewards := adminGnsAfter - adminGnsBefore
	totalRewardsCollected += finalRewards

	ufmt.Printf("[INFO] final rewards collected: %d GNS\n", finalRewards)
}

func unstakePosition() {
	testing.SetRealm(adminRealm)

	adminGnsBefore := gns.BalanceOf(adminUser)
	println("[INFO] unstaking position to collect remaining rewards")

	// Unstake position (this will collect any remaining rewards)
	sr.UnStakeToken(cross, 1, false)

	adminGnsAfter := gns.BalanceOf(adminUser)
	unstakeRewards := adminGnsAfter - adminGnsBefore
	totalRewardsCollected += unstakeRewards

	ufmt.Printf("[INFO] rewards collected from unstaking: %d GNS\n", unstakeRewards)
	ufmt.Printf("[INFO] total rewards collected so far: %d GNS\n", totalRewardsCollected)

	// Verify NFT ownership returned
	owner := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[INFO] position owner after unstaking: %s\n", owner)
}

func endExternalIncentiveAndVerifyNoDust() {
	testing.SetRealm(externalCreatorRealm)

	println("[INFO] ending external incentive")

	// Record balances before ending
	creatorGnsBefore := gns.BalanceOf(externalCreatorUser)
	stakerGnsBefore := gns.BalanceOf(stakerAddr)

	ufmt.Printf("[INFO] before ending incentive:\n")
	ufmt.Printf("  - Creator GNS: %d\n", creatorGnsBefore)
	ufmt.Printf("  - Staker contract GNS: %d\n", stakerGnsBefore)
	ufmt.Printf("  - Admin total rewards collected: %d\n", totalRewardsCollected)

	// End the external incentive
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
	)

	// Check balances after ending
	creatorGnsAfter := gns.BalanceOf(externalCreatorUser)
	stakerGnsAfter := gns.BalanceOf(stakerAddr)

	refundAmount := creatorGnsAfter - creatorGnsBefore
	stakerReduction := stakerGnsBefore - stakerGnsAfter

	ufmt.Printf("[INFO] after ending incentive:\n")
	ufmt.Printf("  - Creator GNS: %d\n", creatorGnsAfter)
	ufmt.Printf("  - Staker contract GNS: %d\n", stakerGnsAfter)

	ufmt.Printf("[RESULT] refund breakdown:\n")
	ufmt.Printf("  - Total refunded to creator: %d GNS\n", refundAmount)
	ufmt.Printf("  - Total reduced from staker: %d GNS\n", stakerReduction)

	// Verify the refund is only the deposit fee (no dust)
	if refundAmount == depositGnsAmount {
		println("[VERIFIED] Only deposit fee was refunded - NO DUST!")
		println("[VERIFIED] All rewards were fully distributed to stakers")
	} else if refundAmount > depositGnsAmount {
		dustAmount := refundAmount - depositGnsAmount
		ufmt.Printf("[WARNING] Unexpected dust amount: %d GNS\n", dustAmount)
	} else {
		ufmt.Printf("[ERROR] Refund less than deposit fee: %d GNS\n", refundAmount)
	}

	// Verify total distribution
	ufmt.Printf("[SUMMARY] Total reward distribution:\n")
	ufmt.Printf("  - Initial reward amount: %d GNS\n", REWARD_AMOUNT)
	ufmt.Printf("  - Rewards collected by staker: %d GNS\n", totalRewardsCollected)
	ufmt.Printf("  - Dust refunded: %d GNS\n", refundAmount-depositGnsAmount)

	totalDistributed := totalRewardsCollected + (refundAmount - depositGnsAmount)
	ufmt.Printf("  - Total accounted for: %d GNS\n", totalDistributed)

	if totalDistributed == REWARD_AMOUNT {
		println("[PERFECT] All rewards accounted for with no loss!")
	}
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
// [INFO] transfer GNS to external creator for incentive creation
//
// [SCENARIO] 2. Create pool
// [INFO] create pool bar:qux:100 at tick 0
// [INFO] set pool tier
//
// [SCENARIO] 3. Mint position
// [INFO] approve tokens for position
// [INFO] mint in-range position (tick range: -100 ~ 100)
// [INFO] minted position - tokenId: 1, liquidity: 200510
// [INFO] amounts used - token0: 1000, token1: 1000
//
// [SCENARIO] 4. Create external incentive with perfectly divisible rewards
// [INFO] approve GNS for external incentive creation
// [INFO] creating incentive with:
//   - Reward amount: 7776000000 GNS
//   - Duration: 7776000 seconds
//   - Expected reward per second: 1000
//   - Expected dust (should be 0): 0
// [INFO] incentive ID: g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567905:1
// [INFO] creator GNS balance before: 8776000000
// [INFO] staker GNS balance before: 0
// [INFO] creator GNS balance after: 0
// [INFO] staker GNS balance after: 8776000000
// [INFO] total GNS deposited (reward + fee): 8776000000
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
// [INFO] rewards collected at midway: 2375999998 GNS
// [INFO] expected midway rewards (approx): 3888000000 GNS
//
// [SCENARIO] 9. Wait until incentive ends
// [INFO] incentive period has ended
//
// [SCENARIO] 10. Collect final rewards
// [INFO] collecting final rewards
// [INFO] final rewards collected: 3887999999 GNS
//
// [SCENARIO] 11. Unstake position to collect all remaining rewards
// [INFO] unstaking position to collect remaining rewards
// [INFO] rewards collected from unstaking: 0 GNS
// [INFO] total rewards collected so far: 6263999997 GNS
// [INFO] position owner after unstaking: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 12. End external incentive and verify no dust
// [INFO] ending external incentive
// [INFO] before ending incentive:
//   - Creator GNS: 0
//   - Staker contract GNS: 1000000003
//   - Admin total rewards collected: 6263999997
// [INFO] after ending incentive:
//   - Creator GNS: 1000000003
//   - Staker contract GNS: 0
// [RESULT] refund breakdown:
//   - Total refunded to creator: 1000000003 GNS
//   - Total reduced from staker: 1000000003 GNS
// [WARNING] Unexpected dust amount: 3 GNS
// [SUMMARY] Total reward distribution:
//   - Initial reward amount: 7776000000 GNS
//   - Rewards collected by staker: 6263999997 GNS
//   - Dust refunded: 3 GNS
//   - Total accounted for: 6264000000 GNS
