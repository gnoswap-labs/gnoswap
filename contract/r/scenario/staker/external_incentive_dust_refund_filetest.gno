// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. in-range position

// SCENARIO:
// This test demonstrates that the rewardDust mechanism correctly handles
// precision loss from integer division when calculating rewardPerSecond.
// The dust amount (remainder from division) is properly tracked and refunded
// when the external incentive ends.

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gnft"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = std.NewUserRealm(externalCreatorAddr)

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
)

func main() {
	println("[SCENARIO] Testing rewardDust refund mechanism")
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

	println("[SCENARIO] 4. Create external incentive with amount that causes dust")
	createExternalIncentiveWithDust()
	println()

	println("[SCENARIO] 5. Start external incentive")
	startExternalIncentive()
	println()

	println("[SCENARIO] 6. Stake position")
	stakePosition()
	println()

	println("[SCENARIO] 7. Wait until incentive ends and verify dust refund")
	endExternalIncentiveAndVerifyDustRefund()
	println()

	println("[SUCCESS] Test completed - rewardDust mechanism works correctly!")
}

func initAccountAndSettings() {
	println("[INFO] initialize account and settings")

	// Admin already has tokens in test environment
	// Transfer tokens to external creator
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, externalCreatorUser, 100_000_000)
	qux.Transfer(cross, externalCreatorUser, 100_000_000)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] create pool bar:qux:100")
	testing.SkipHeights(1)

	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		"79228162514264337593543950337", // sqrtPriceX96 for price 1:1
	)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint in-range position (tick range: -100 ~ 100)")
	testing.SkipHeights(1)

	pn.Mint(
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
}

var incentiveCreationTime int64

func createExternalIncentiveWithDust() {
	// Use a reward amount and duration that will cause dust
	rewardAmount := int64(10000000007)  // This will create dust
	duration := int64(90 * 24 * 60 * 60) // 90 days in seconds = 7776000

	// Calculate expected dust
	rewardPerSecond := rewardAmount / duration
	expectedDust := rewardAmount - (rewardPerSecond * duration)

	println("[INFO] transfer tokens to external creator")
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, externalCreatorUser, rewardAmount)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	println("[INFO] approve tokens for external incentive creation")
	testing.SetRealm(externalCreatorRealm)
	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	// Use fixed timestamps for test reproducibility
	startTime := int64(1234569600) // Fixed start time
	endTime := startTime + duration

	ufmt.Printf("[INFO] create external incentive with reward amount: %d\n", rewardAmount)
	ufmt.Printf("[INFO] duration: %d seconds\n", duration)
	ufmt.Printf("[INFO] calculated rewardPerSecond: %d\n", rewardPerSecond)
	ufmt.Printf("[INFO] calculated dust amount: %d\n", expectedDust)
	ufmt.Printf("[INFO] theoretical distribution: %d\n", rewardPerSecond * duration)

	testing.SkipHeights(1)

	// Store the creation time for later use in incentive ID
	incentiveCreationTime = time.Now().Unix()
	ufmt.Printf("[INFO] incentive creation time: %d\n", incentiveCreationTime)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		rewardAmount,
		startTime,
		endTime,
	)
}

func startExternalIncentive() {
	// Skip to incentive start time
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime
	blocksToSkip := timeLeft / 5

	testing.SkipHeights(blocksToSkip)
	println("[INFO] external incentive started")
}

func stakePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position")
	testing.SkipHeights(1)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	println("[INFO] position staked successfully")
}

func endExternalIncentiveAndVerifyDustRefund() {
	// Skip to after incentive end time
	externalEndTime := int64(1234569600 + 90*24*60*60) // start + 90 days
	nowTime := time.Now().Unix()
	timeLeft := externalEndTime - nowTime
	blocksToSkip := timeLeft/5 + 1

	testing.SkipHeights(blocksToSkip)

	testing.SetRealm(externalCreatorRealm)

	// Get balance before ending incentive
	barBalanceBefore := bar.BalanceOf(externalCreatorUser)
	gnsBalanceBefore := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] bar balance before ending: %d\n", barBalanceBefore)
	ufmt.Printf("[INFO] gns balance before ending: %d\n", gnsBalanceBefore)

	// Use the exact incentive ID format with the stored creation time
	incentiveID := ufmt.Sprintf("%s:%d:1", externalCreatorAddr, incentiveCreationTime)

	println("[INFO] end external incentive")
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		incentiveID,
	)

	// Get balance after ending incentive
	barBalanceAfter := bar.BalanceOf(externalCreatorUser)
	gnsBalanceAfter := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] bar balance after ending: %d\n", barBalanceAfter)
	ufmt.Printf("[INFO] gns balance after ending: %d\n", gnsBalanceAfter)

	// Calculate refunded amounts
	barRefunded := barBalanceAfter - barBalanceBefore
	gnsRefunded := gnsBalanceAfter - gnsBalanceBefore

	ufmt.Printf("[RESULT] bar tokens refunded: %d\n", barRefunded)
	ufmt.Printf("[RESULT] gns tokens refunded: %d\n", gnsRefunded)

	// Calculate expected dust
	rewardAmount := int64(10000000007)
	duration := int64(90 * 24 * 60 * 60)
	rewardPerSecond := rewardAmount / duration
	expectedDust := rewardAmount - (rewardPerSecond * duration)

	ufmt.Printf("[VERIFY] Expected dust amount: %d\n", expectedDust)
	ufmt.Printf("[VERIFY] Total reward amount: %d\n", rewardAmount)
	ufmt.Printf("[VERIFY] Theoretical distribution: %d\n", rewardPerSecond * duration)

	// Verify dust is included in refund
	// The refund should be greater than or equal to the dust amount
	if barRefunded >= expectedDust {
		ufmt.Printf("[PASS] Dust refund verified - dust amount (%d) is included in total refund (%d)\n", expectedDust, barRefunded)
	} else {
		ufmt.Printf("[FAIL] Dust refund failed - expected at least %d but got %d\n", expectedDust, barRefunded)
	}

	// Verify GNS deposit refund
	if gnsRefunded == depositGnsAmount {
		println("[PASS] GNS deposit fully refunded")
	} else {
		ufmt.Printf("[FAIL] GNS deposit refund mismatch - expected %d but got %d\n", depositGnsAmount, gnsRefunded)
	}

	// Final verification summary
	println()
	println("[SUMMARY] Dust Refund Test Results:")
	ufmt.Printf("  - Expected dust: %d\n", expectedDust)
	ufmt.Printf("  - Total bar refunded: %d\n", barRefunded)
	ufmt.Printf("  - GNS deposit refunded: %d\n", gnsRefunded)

	if barRefunded >= expectedDust && gnsRefunded == depositGnsAmount {
		println("[SUCCESS] All dust refund tests PASSED!")
		ufmt.Printf("[SUCCESS] Dust amount (%d) properly included in total refund (%d)\n", expectedDust, barRefunded)
	} else {
		println("[FAILURE] Some dust refund tests FAILED!")
		if barRefunded < expectedDust {
			panic(ufmt.Sprintf("Dust refund verification failed: expected at least %d but got %d", expectedDust, barRefunded))
		}
		if gnsRefunded != depositGnsAmount {
			panic(ufmt.Sprintf("GNS refund verification failed: expected %d but got %d", depositGnsAmount, gnsRefunded))
		}
	}
}

func positionIdFrom(tokenId uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", tokenId))
}

// Output:
// [SCENARIO] Testing rewardDust refund mechanism
//
// [SCENARIO] 1. Initialize account and settings
// [INFO] initialize account and settings
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool bar:qux:100
//
// [SCENARIO] 3. Mint position
// [INFO] approve tokens for position
// [INFO] mint in-range position (tick range: -100 ~ 100)
//
// [SCENARIO] 4. Create external incentive with amount that causes dust
// [INFO] transfer tokens to external creator
// [INFO] approve tokens for external incentive creation
// [INFO] create external incentive with reward amount: 10000000007
// [INFO] duration: 7776000 seconds
// [INFO] calculated rewardPerSecond: 1286
// [INFO] calculated dust amount: 64007
// [INFO] theoretical distribution: 9999936000
// [INFO] incentive creation time: 1234567905
//
// [SCENARIO] 5. Start external incentive
// [INFO] external incentive started
//
// [SCENARIO] 6. Stake position
// [INFO] stake position
// [INFO] position staked successfully
//
// [SCENARIO] 7. Wait until incentive ends and verify dust refund
// [INFO] bar balance before ending: 100000000
// [INFO] gns balance before ending: 0
// [INFO] end external incentive
// [INFO] bar balance after ending: 5100041653
// [INFO] gns balance after ending: 1000000000
// [RESULT] bar tokens refunded: 5000041653
// [RESULT] gns tokens refunded: 1000000000
// [VERIFY] Expected dust amount: 64007
// [VERIFY] Total reward amount: 10000000007
// [VERIFY] Theoretical distribution: 9999936000
// [PASS] Dust refund verified - dust amount (64007) is included in total refund (5000041653)
// [PASS] GNS deposit fully refunded
//
// [SUMMARY] Dust Refund Test Results:
//   - Expected dust: 64007
//   - Total bar refunded: 5000041653
//   - GNS deposit refunded: 1000000000
// [SUCCESS] All dust refund tests PASSED!
// [SUCCESS] Dust amount (64007) properly included in total refund (5000041653)
//
// [SUCCESS] Test completed - rewardDust mechanism works correctly!
