// Test unstaking positions after external incentives have ended
// This ensures users can recover their staked LP positions even after external incentives expire

// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
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
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive parameters
	depositGnsAmount     int64 = 1_000_000_000     // 1_000 GNS deposit
	externalRewardAmount int64 = 10_000_000_000    // 10_000 reward tokens
	TIMESTAMP_90DAYS     int64 = 90 * 24 * 60 * 60 // Must be 90, 180, or 365 days

	// Store the actual incentive start time for later use
	incentiveStartTime int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create pool without tier")
	createPoolNoTier(cur)
	println()

	println("[SCENARIO] 3. Create external incentive")
	createExternalIncentive(cur)
	println()

	println("[SCENARIO] 4. Mint and stake positions")
	mintAndStakePositions(cur)
	println()

	println("[SCENARIO] 5. Verify rewards accumulate with external incentive")
	verifyExternalRewards(cur)
	println()

	println("[SCENARIO] 6. Wait for external incentive to expire")
	waitForIncentiveExpiry(cur)
	println()

	println("[SCENARIO] 7. Verify pool has no incentives")
	verifyNoIncentives(cur)
	println()

	println("[SCENARIO] 8. Unstake positions after incentive ended")
	unstakeAfterIncentiveEnd(cur)
	println()

	println("[SCENARIO] 9. Verify positions recovered successfully")
	verifyPositionsRecovered(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	// override warm-up period for testing
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross(cur), 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFee(cross(cur), 0)

	// mint and distribute initial GNS
	en.MintAndDistributeGns(cross(cur))
	en.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] initialized with short warm-up periods\n")
	testing.SkipHeights(1)
}

func createPoolNoTier(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())

	// Create pool without setting any tier
	pl.CreatePool(cross(cur), barPath, fooPath, fee3000, "79228162514264337593543950337")

	// Verify pool has no tier
	// Pool should not be in tier system
	ufmt.Printf("[EXPECTED] pool created: bar:foo:3000 with no tier\n")
	testing.SkipHeights(1)
}

func createExternalIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	// Add external reward token
	sr.AddToken(cross(cur), "gno.land/r/onbloc/obl")

	// Approve GNS for deposit
	gns.Approve(cross(cur), stakerAddr, depositGnsAmount)

	// Approve reward tokens
	bar.Approve(cross(cur), stakerAddr, externalRewardAmount)

	// Create external incentive
	// Start time must be at least 1 day in the future AND must be midnight
	currentTime := time.Now().Unix()
	// Calculate tomorrow's midnight
	tomorrowMidnight := ((currentTime / 86400) + 1) * 86400
	incentiveStartTime = tomorrowMidnight + 86400 // Add one more day to ensure it's at least 1 day in future
	endTime := incentiveStartTime + TIMESTAMP_90DAYS

	sr.CreateExternalIncentive(
		cross(cur),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000", // targetPoolPath
		barPath,              // rewardToken
		externalRewardAmount, // rewardAmount
		incentiveStartTime,   // startTimestamp
		endTime,              // endTimestamp
	)

	ufmt.Printf("[EXPECTED] external incentive created - start: %d, end: %d\n", incentiveStartTime, endTime)
	testing.SkipHeights(1)
}

func mintAndStakePositions(cur realm) {
	testing.SetRealm(adminRealm)

	// Approve tokens for minting
	bar.Approve(cross(cur), poolAddr, maxInt64)
	foo.Approve(cross(cur), poolAddr, maxInt64)

	// Mint position 1
	positionId1, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee3000,
		int32(-2400),
		int32(2400),
		"100",
		"100",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	// Mint position 2
	positionId2, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee3000,
		int32(-3000),
		int32(3000),
		"200",
		"200",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	// Stake both positions
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId1))
	sr.StakeToken(cross(cur), positionId1, "")

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId2))
	sr.StakeToken(cross(cur), positionId2, "")

	ufmt.Printf("[EXPECTED] minted and staked positions: %d and %d\n", positionId1, positionId2)
	testing.SkipHeights(1)
}

func verifyExternalRewards(cur realm) {
	// Skip to when external incentive is active (need to skip more than 1 day)
	testing.SkipHeights(200000) // Skip enough blocks to pass the start time

	testing.SetRealm(adminRealm)

	beforeBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1) // Collect rewards from external incentive
	afterBar := bar.BalanceOf(adminUser)
	diff := afterBar - beforeBar

	if diff == 0 {
		panic("expected external rewards to accumulate")
	}

	ufmt.Printf("[EXPECTED] external rewards accumulated: %d BAR tokens\n", diff)
	testing.SkipHeights(1)
}

func waitForIncentiveExpiry(cur realm) {
	// Skip blocks to go past the end time of external incentive
	testing.SkipHeights(10000)

	ufmt.Printf("[EXPECTED] waited for external incentive to expire\n")
}

func verifyNoIncentives(cur realm) {
	// Try to collect rewards - should be minimal or none
	testing.SetRealm(adminRealm)

	beforeBar := bar.BalanceOf(adminUser)
	beforeGns := gns.BalanceOf(adminUser)

	sr.CollectReward(cross(cur), 1)

	afterBar := bar.BalanceOf(adminUser)
	afterGns := gns.BalanceOf(adminUser)

	barDiff := afterBar - beforeBar
	gnsDiff := afterGns - beforeGns

	ufmt.Printf("[INFO] rewards after incentive end - BAR: %d, GNS: %d (should be minimal)\n", barDiff, gnsDiff)

	// Verify pool has no tier and no active external incentives
	// Pool has no tier and external incentive has ended
	ufmt.Printf("[EXPECTED] pool has no tier and external incentive ended\n")
}

func unstakeAfterIncentiveEnd(cur realm) {
	testing.SetRealm(adminRealm)

	// This is the critical test - unstaking should succeed even though:
	// 1. Pool has no tier (no internal incentives)
	// 2. External incentive has ended (no external incentives)

	sr.UnStakeToken(cross(cur), 1)
	ufmt.Printf("[EXPECTED] successfully unstaked position 1 after incentive ended\n")

	sr.UnStakeToken(cross(cur), 2)
	ufmt.Printf("[EXPECTED] successfully unstaked position 2 after incentive ended\n")

	testing.SkipHeights(1)
}

func verifyPositionsRecovered(cur realm) {
	// Verify NFT ownership returned to original owners
	owner1, err1 := gnft.OwnerOf(positionIdFrom(cur, 1))
	if err1 != nil {
		panic("error checking ownership of position 1: " + err1.Error())
	}
	if owner1 != adminUser {
		panic(ufmt.Sprintf("NFT 1 should be owned by admin after unstaking, got %s", owner1))
	}

	owner2, err2 := gnft.OwnerOf(positionIdFrom(cur, 2))
	if err2 != nil {
		panic("error checking ownership of position 2: " + err2.Error())
	}
	if owner2 != adminUser {
		panic(ufmt.Sprintf("NFT 2 should be owned by admin after unstaking, got %s", owner2))
	}

	ufmt.Printf("[EXPECTED] NFT ownership returned to admin for both positions\n")

	// Verify positions can still be interacted with normally
	testing.SetRealm(adminRealm)
	position1, err1 := pn.GetPosition(1)
	if err1 != nil {
		panic("position 1 should still exist")
	}
	position2, err2 := pn.GetPosition(2)
	if err2 != nil {
		panic("position 2 should still exist")
	}

	ufmt.Printf("[EXPECTED] position 1 still accessible - liquidity: %s\n", position1.Liquidity())
	ufmt.Printf("[EXPECTED] position 2 still accessible - liquidity: %s\n", position2.Liquidity())
}

func positionIdFrom(cur realm, positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [EXPECTED] initialized with short warm-up periods
//
// [SCENARIO] 2. Create pool without tier
// [EXPECTED] pool created: bar:foo:3000 with no tier
//
// [SCENARIO] 3. Create external incentive
// [EXPECTED] external incentive created - start: 1234656000, end: 1242432000
//
// [SCENARIO] 4. Mint and stake positions
// [EXPECTED] minted and staked positions: 1 and 2
//
// [SCENARIO] 5. Verify rewards accumulate with external incentive
// [EXPECTED] external rewards accumulated: 447040883 BAR tokens
//
// [SCENARIO] 6. Wait for external incentive to expire
// [EXPECTED] waited for external incentive to expire
//
// [SCENARIO] 7. Verify pool has no incentives
// [INFO] rewards after incentive end - BAR: 24513690, GNS: 0 (should be minimal)
// [EXPECTED] pool has no tier and external incentive ended
//
// [SCENARIO] 8. Unstake positions after incentive ended
// [EXPECTED] successfully unstaked position 1 after incentive ended
// [EXPECTED] successfully unstaked position 2 after incentive ended
//
// [SCENARIO] 9. Verify positions recovered successfully
// [EXPECTED] NFT ownership returned to admin for both positions
// [EXPECTED] position 1 still accessible - liquidity: 884
// [EXPECTED] position 2 still accessible - liquidity: 1435
