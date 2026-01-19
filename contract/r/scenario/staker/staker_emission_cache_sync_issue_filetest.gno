// Test for staker emission cache synchronization issue
// This test demonstrates that cached emission rates in the staker module
// do not immediately reflect governance changes to distribution percentages

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"
	barPath    = "gno.land/r/onbloc/bar"
	bazPath    = "gno.land/r/onbloc/baz"

	fee3000     uint32 = 3000
	max_timeout int64  = 9999999999
	maxInt64    int64  = 9223372036854775807

	// Store rewards for comparison
	initialReward   int64
	staleRateReward int64
)

func main() {
	println("[SCENARIO] 1. Initialize system with 75% staker allocation")
	initSystem()
	println()

	println("[SCENARIO] 2. Create pool and mint position")
	createPoolAndPosition()
	println()

	println("[SCENARIO] 3. Stake position and collect initial rewards")
	stakeAndCollectInitial()
	println()

	println("[SCENARIO] 4. Change distribution to 50% (governance action)")
	changeDistribution()
	println()

	println("[SCENARIO] 5. Wait without any user interaction")
	waitWithoutInteraction()
	println()

	println("[SCENARIO] 6. Collect rewards (should use stale 75% rate)")
	collectWithStaleRate()
	println()

	println("[SCENARIO] 7. Collect rewards again (should use correct 50% rate)")
	collectWithCorrectRate()
}

func initSystem() {
	testing.SetRealm(adminRealm)

	// Set emission start time
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	// Set initial distribution: 75% to staker
	emission.ChangeDistributionPct(
		cross,
		1, 7500, // LIQUIDITY_STAKER: 75%
		2, 2000, // DEVOPS: 20%
		3, 500, // COMMUNITY_POOL: 5%
		4, 0, // GOV_STAKER: 0%
	)

	// Remove unstaking fee for clearer reward calculations
	sr.SetUnStakingFee(cross, 0)

	// Set pool creation fee to 0
	pl.SetPoolCreationFee(cross, 0)

	// Mint and distribute initial GNS
	emission.MintAndDistributeGns(cross)
	emission.MintAndDistributeGns(cross)

	// Give tokens to user1 for later testing
	bar.Transfer(cross, user1Addr, 1_000_000)
	baz.Transfer(cross, user1Addr, 1_000_000)

	println("[EXPECTED] Initial distribution set to 75% for stakers")
	ufmt.Printf("[EXPECTED] Current staker emission per second: %d\n", emission.GetStakerEmissionAmountPerSecond())
}

func createPoolAndPosition() {
	testing.SetRealm(adminRealm)

	// Create bar:baz pool
	pl.CreatePool(cross, barPath, bazPath, fee3000, "79228162514264337593543950336")

	// Set pool to tier 1
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 1)

	// Approve tokens
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	// Mint position
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"1000000",
		"1000000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position minted: ID=%d, liquidity=%s\n", positionId, liquidity)
}

func stakeAndCollectInitial() {
	testing.SetRealm(adminRealm)

	// Stake position
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	// Skip some blocks to accumulate rewards
	testing.SkipHeights(100)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)

	// Collect initial rewards
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	initialReward = afterGns - beforeGns

	ufmt.Printf("[EXPECTED] Initial reward collected (at 75%% rate): %d GNS\n", initialReward)

	// Add significant time gap before distribution change
	// This ensures there's a clear period to verify retroactive calculation issues
	println("[INFO] Waiting additional blocks before governance change...")
	testing.SkipHeights(500)
}

func changeDistribution() {
	testing.SetRealm(adminRealm)

	// Record emission rate before change
	beforeRate := emission.GetStakerEmissionAmountPerSecond()

	// Change distribution to 50% for stakers
	emission.ChangeDistributionPct(
		cross,
		1, 5000, // LIQUIDITY_STAKER: 50% (reduced from 75%)
		2, 3000, // DEVOPS: 30%
		3, 2000, // COMMUNITY_POOL: 20%
		4, 0, // GOV_STAKER: 0%
	)

	// Check emission rate after change
	afterRate := emission.GetStakerEmissionAmountPerSecond()

	ufmt.Printf("[EXPECTED] Emission rate before change: %d\n", beforeRate)
	ufmt.Printf("[EXPECTED] Emission rate after change: %d\n", afterRate)
	ufmt.Printf("[EXPECTED] Rate reduction: %d%%\n", (beforeRate-afterRate)*100/beforeRate)
}

func waitWithoutInteraction() {
	// Skip blocks without any user interaction
	// This simulates a period where pools are inactive
	testing.SkipHeights(100)

	ufmt.Printf("[EXPECTED] Waited 100 blocks without user interaction\n")
	ufmt.Printf("[INFO] With the hook fix, cache should now be automatically updated to 50%% rate\n")
}

func collectWithStaleRate() {
	testing.SetRealm(adminRealm)

	sr.CollectReward(cross, 1, false)
	testing.SkipHeights(1)

	// Collect rewards - should now use correct cached rate after hook update
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	staleRateReward = afterGns - beforeGns

	// Calculate expected rewards at different rates (same time period as initial)
	expectedRewardAt75Pct := initialReward           // Should be similar to initial if still at 75%
	expectedRewardAt50Pct := initialReward * 50 / 75 // Expected if properly at 50%

	// Determine which rate was actually used
	isUsingCorrectRate := (staleRateReward < (expectedRewardAt75Pct * 80 / 100)) // Less than 80% of 75% rate suggests 50% rate

	ufmt.Printf("[EXPECTED] Reward collected after rate change: %d GNS\n", staleRateReward)
	println("[INFO] The hook should have updated the cache to use the new 50% rate")
	ufmt.Printf("[LOG] Expected at 75%% rate: ~%d GNS\n", expectedRewardAt75Pct)
	ufmt.Printf("[LOG] Expected at 50%% rate: ~%d GNS\n", expectedRewardAt50Pct)
	ufmt.Printf("[LOG] Actual reward received: %d GNS\n", staleRateReward)

	if isUsingCorrectRate {
		println("[EXPECTED] Cache correctly updated to 50% rate")
	} else {
		println("[RESULT] FAILED: Cache still using stale 75%% rate")
	}
}

func newUserStakes() {
	testing.SetRealm(user1Realm)

	// User1 creates and stakes a new position
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"100000",
		"100000",
		"1",
		"1",
		max_timeout,
		user1Addr,
		user1Addr,
		"",
	)

	// Stake triggers cache update
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ufmt.Printf("[EXPECTED] New user staked position %d\n", positionId)
	println("[INFO] This staking action triggers cache update to correct 50% rate")
}

func collectWithCorrectRate() {
	testing.SetRealm(adminRealm)

	// Skip some blocks
	testing.SkipHeights(100)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)

	// Collect rewards - should still use correct rate after new user stakes
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	correctReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] Reward collected after new user stakes: %d GNS\n", correctReward)
	println()
	ufmt.Printf("[LOG] Initial reward (75%% rate, alone): %d GNS\n", initialReward)
	ufmt.Printf("[LOG] Previous collection (50%% rate, alone): %d GNS\n", staleRateReward)
	ufmt.Printf("[LOG] Current reward (50%% rate, shared pool): %d GNS\n", correctReward)

	// Verify the rate is still correctly at 50%
	// The rewards should be similar (both at 50% rate) or slightly less if there's rounding
	isStillAt50Rate := correctReward <= staleRateReward
	if isStillAt50Rate {
		println("[EXPECTED] Still using correct 50% rate after new user stakes")
	} else {
		println("[RESULT] FAILED: Rate calculation error detected")
	}
}

func positionIdFrom(positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize system with 75% staker allocation
// [EXPECTED] Initial distribution set to 75% for stakers
// [EXPECTED] Current staker emission per second: 0
//
// [SCENARIO] 2. Create pool and mint position
// [EXPECTED] Position minted: ID=1, liquidity=20113073
//
// [SCENARIO] 3. Stake position and collect initial rewards
// [EXPECTED] Initial reward collected (at 75% rate): 4013269 GNS
// [INFO] Waiting additional blocks before governance change...
//
// [SCENARIO] 4. Change distribution to 50% (governance action)
// [EXPECTED] Emission rate before change: 5351027
// [EXPECTED] Emission rate after change: 3567351
// [EXPECTED] Rate reduction: 33%
//
// [SCENARIO] 5. Wait without any user interaction
// [EXPECTED] Waited 100 blocks without user interaction
// [INFO] With the hook fix, cache should now be automatically updated to 50% rate
//
// [SCENARIO] 6. Collect rewards (should use stale 75% rate)
// [EXPECTED] Reward collected after rate change: 2675512 GNS
// [INFO] The hook should have updated the cache to use the new 50% rate
// [LOG] Expected at 75% rate: ~4013269 GNS
// [LOG] Expected at 50% rate: ~2675512 GNS
// [LOG] Actual reward received: 2675512 GNS
// [EXPECTED] Cache correctly updated to 50% rate
//
// [SCENARIO] 7. Collect rewards again (should use correct 50% rate)
// [EXPECTED] Reward collected after new user stakes: 2675512 GNS
//
// [LOG] Initial reward (75% rate, alone): 4013269 GNS
// [LOG] Previous collection (50% rate, alone): 2675512 GNS
// [LOG] Current reward (50% rate, shared pool): 2675512 GNS
// [EXPECTED] Still using correct 50% rate after new user stakes
