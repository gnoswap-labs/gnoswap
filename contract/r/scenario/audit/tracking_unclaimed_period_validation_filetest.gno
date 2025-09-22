// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gnft"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	emissionAddr, _ = access.GetAddress(prabc.ROLE_EMISSION.String())

	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

	// Test result tracking
	testsPassed int
	testsFailed int
)

func main() {
	println("==========================================================")
	println("VULNERABILITY VALIDATION TEST: processUnclaimableReward")
	println("==========================================================")
	println()
	println("This test validates if the bug is fixed by checking specific conditions")
	println()

	// Reset test counters
	testsPassed = 0
	testsFailed = 0

	println("[TEST 1] Pool Initialization Check")
	println("----------------------------------------------------------")
	testPoolInitialization()

	println()
	println("[TEST 2] Attack Vector 1 - CollectReward During Unclaimable")
	println("----------------------------------------------------------")
	testAttackVector1WithValidation()

	println()
	println("[TEST 3] Attack Vector 2 - CollectReward During Claimable")
	println("----------------------------------------------------------")
	testAttackVector2WithValidation()

	println()
	println("==========================================================")
	println("TEST SUMMARY")
	println("==========================================================")
	ufmt.Printf("Tests Passed: %d\n", testsPassed)
	ufmt.Printf("Tests Failed: %d\n", testsFailed)

	if testsFailed == 0 {
		println("✅ ALL TESTS PASSED - BUG IS FIXED!")
	} else {
		println("❌ SOME TESTS FAILED - BUG STILL EXISTS!")
	}
}

// Test 1: Verify pool initialization
func testPoolInitialization() {
	println("[SETUP] Initialize and create pool")
	initAndSetup()
	createPool()
	setPoolToTier1()

	println("\n[VALIDATION POINT 1] Check initial lastUnclaimableTime")
	// In the current buggy implementation, lastUnclaimableTime is set to currentTime
	// In the fixed implementation, it should be 0

	println("Expected: lastUnclaimableTime = 0 (no unclaimable period)")
	println("Note: Cannot directly access internal state, inferring from behavior")

	// Create and stake a position
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	positionId := mintAndStakePosition(-100, 100, "1000", "1000")

	// Immediately collect reward to check if any unclaimable is sent
	communityBalanceBefore := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter := gns.BalanceOf(communityPoolAddr)
	unclaimableSent := communityBalanceAfter - communityBalanceBefore

	if unclaimableSent > 0 {
		ufmt.Printf("❌ FAILED: %d tokens sent to community pool (should be 0)\n", unclaimableSent)
		ufmt.Printf("   This indicates lastUnclaimableTime was incorrectly initialized\n")
		testsFailed++
	} else {
		println("✅ PASSED: No unclaimable rewards sent on first collection")
		println("   This indicates correct initialization")
		testsPassed++
	}

	// Cleanup - unstake for next test
	sr.UnStakeToken(cross, positionId, false)
	testing.SkipHeights(5)
}

// Test 2: Attack Vector 1 with validation
func testAttackVector1WithValidation() {
	println("[SETUP] Create and stake new position")
	testing.SetRealm(adminRealm)

	positionId := mintAndStakePosition(-200, 200, "2000", "2000")
	// claimableStartTime := time.Now().Unix()

	println("\n[STEP 1] Accumulate rewards for 10 blocks while claimable")
	testing.SkipHeights(10)

	println("\n[STEP 2] Unstake to enter unclaimable period")
	sr.UnStakeToken(cross, positionId, false)
	actualUnclaimableStart := time.Now().Unix()
	ufmt.Printf("Unclaimable period started at: %d\n", actualUnclaimableStart)

	println("\n[STEP 3] Wait 5 blocks, then collect during unclaimable")
	testing.SkipHeights(5)
	attackTime := time.Now().Unix()

	// Re-stake temporarily to collect
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	communityBalanceBefore1 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter1 := gns.BalanceOf(communityPoolAddr)
	unclaimableRound1 := communityBalanceAfter1 - communityBalanceBefore1

	// Unstake again
	sr.UnStakeToken(cross, positionId, false)

	println("\n[STEP 4] Wait 5 more blocks, then stake and collect again")
	testing.SkipHeights(5)

	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")
	endTime := time.Now().Unix()

	communityBalanceBefore2 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter2 := gns.BalanceOf(communityPoolAddr)
	unclaimableRound2 := communityBalanceAfter2 - communityBalanceBefore2

	println("\n[VALIDATION POINT 2] Check reward distribution")

	totalUnclaimableDuration := endTime - actualUnclaimableStart
	attackDuration := attackTime - actualUnclaimableStart
	remainingDuration := endTime - attackTime

	ufmt.Printf("Total unclaimable period: %d seconds\n", totalUnclaimableDuration)
	ufmt.Printf("First collection at: +%d seconds (sent: %d)\n", attackDuration, unclaimableRound1)
	ufmt.Printf("Second collection at: +%d seconds (sent: %d)\n", remainingDuration, unclaimableRound2)

	totalSent := unclaimableRound1 + unclaimableRound2

	// Validation logic
	// If bug exists: First collection resets timer, losing early rewards
	// If fixed: Both collections should have proportional rewards

	if unclaimableRound1 == 0 && unclaimableRound2 > 0 {
		println("❌ FAILED: First collection sent nothing, second sent rewards")
		println("   This indicates rewards before attack were lost (BUG EXISTS)")
		testsFailed++
	} else if unclaimableRound1 > 0 && unclaimableRound2 > 0 {
		// Check if proportions are roughly correct
		// Round1 should be ~50% of total (5 blocks out of 10)
		proportion := (unclaimableRound1 * 100) / totalSent
		ufmt.Printf("First collection proportion: %d%%\n", proportion)

		if proportion >= 40 && proportion <= 60 {
			println("✅ PASSED: Rewards distributed proportionally")
			println("   This indicates lastUnclaimableTime was preserved correctly")
			testsPassed++
		} else {
			println("⚠️  WARNING: Unexpected proportion, may indicate partial fix")
			testsFailed++
		}
	} else {
		println("⚠️  UNEXPECTED: Check test setup")
		testsFailed++
	}
}

// Test 3: Attack Vector 2 with validation
func testAttackVector2WithValidation() {
	println("[SETUP] Wait and create new position")
	testing.SkipHeights(100) // Clear state
	testing.SetRealm(adminRealm)

	positionId := mintAndStakePosition(-300, 300, "3000", "3000")

	println("\n[STEP 1] Wait 10 blocks while claimable")
	testing.SkipHeights(10)

	println("\n[STEP 2] Collect reward while pool is claimable")
	attackSetupTime := time.Now().Unix()

	communityBalanceBefore1 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter1 := gns.BalanceOf(communityPoolAddr)
	unclaimableDuringClaimable := communityBalanceAfter1 - communityBalanceBefore1

	ufmt.Printf("Collected at time: %d\n", attackSetupTime)
	ufmt.Printf("Unclaimable sent during claimable: %d\n", unclaimableDuringClaimable)

	println("\n[STEP 3] Unstake to enter unclaimable period")
	sr.UnStakeToken(cross, positionId, false)
	actualUnclaimableStart := time.Now().Unix()

	println("\n[STEP 4] Wait 10 blocks during unclaimable")
	testing.SkipHeights(10)

	println("\n[STEP 5] Stake again and collect")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")
	actualUnclaimableEnd := time.Now().Unix()

	communityBalanceBefore2 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter2 := gns.BalanceOf(communityPoolAddr)
	unclaimableAfterPeriod := communityBalanceAfter2 - communityBalanceBefore2

	println("\n[VALIDATION POINT 3] Check if claimable collection affects tracking")

	actualDuration := actualUnclaimableEnd - actualUnclaimableStart
	ufmt.Printf("Actual unclaimable duration: %d seconds\n", actualDuration)
	ufmt.Printf("Unclaimable sent after period: %d\n", unclaimableAfterPeriod)

	// Validation logic
	if unclaimableDuringClaimable > 0 {
		println("❌ FAILED: Unclaimable rewards sent during claimable period")
		println("   This indicates incorrect state tracking (BUG EXISTS)")
		testsFailed++
	} else {
		println("✅ PASSED: No unclaimable sent during claimable period")
		testsPassed++
	}

	// Additional check: Verify second collection is reasonable
	if unclaimableAfterPeriod == 0 {
		println("⚠️  WARNING: No rewards after actual unclaimable period")
		println("   This might indicate state corruption")
		testsFailed++
	} else {
		println("✅ PASSED: Rewards properly accumulated during unclaimable period")
		testsPassed++
	}

	// Check for overestimation
	// If the bug exists, the calculation would include time from attackSetupTime
	// instead of actualUnclaimableStart
	buggyDuration := actualUnclaimableEnd - attackSetupTime
	if buggyDuration > actualDuration {
		extraDuration := buggyDuration - actualDuration
		ufmt.Printf("⚠️  Potential overestimation by %d seconds\n", extraDuration)

		// We can't directly measure this without knowing the reward rate,
		// but we can flag it as a concern
		if unclaimableAfterPeriod > 0 && unclaimableDuringClaimable > 0 {
			println("❌ FAILED: Evidence of time tracking corruption")
			testsFailed++
		}
	}
}

// Helper functions
func initAndSetup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)
}

func setPoolToTier1() {
	testing.SetRealm(adminRealm)
	sr.SetPoolTier(cross, poolPath, 1)
	testing.SkipHeights(1)
}

func mintAndStakePosition(tickLower, tickUpper int32, amount0, amount1 string) uint64 {
	testing.SetRealm(adminRealm)

	// Mint position
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		tickLower,
		tickUpper,
		amount0,
		amount1,
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	// Stake position
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	return positionId
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}
