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
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

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
	// For 90 days: 10000000007 / 7776000 = 1286 with remainder 7
	// This means rewardDust = 7
	rewardAmount := int64(10000000007)   // This will create dust of 7
	duration := int64(90 * 24 * 60 * 60) // 90 days in seconds

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
	ufmt.Printf("[INFO] expected rewardPerSecond: %d\n", rewardAmount/duration)
	ufmt.Printf("[INFO] expected rewardDust: %d\n", rewardAmount-(rewardAmount/duration)*duration)

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

	// The refund should include:
	// 1. Unallocated rewards (rewards that weren't distributed)
	// 2. The dust amount (64007 in this case based on 10000000007 % 7776000)
	// 3. The full GNS deposit (1_000_000_000)

	// Verify GNS refund
	if gnsRefunded != depositGnsAmount {
		panic(ufmt.Sprintf("Expected GNS refund of %d, but got %d", depositGnsAmount, gnsRefunded))
	}

	// Calculate expected dust
	rewardAmount := int64(10000000007)
	duration := int64(90 * 24 * 60 * 60)
	expectedDust := rewardAmount - (rewardAmount/duration)*duration

	// Verify that dust was included in the refund
	// The refund should be at least the dust amount
	if barRefunded < expectedDust {
		panic(ufmt.Sprintf("Expected refund to include at least dust amount of %d, but got %d", expectedDust, barRefunded))
	}

	// Check if the refund amount makes sense (dust + unallocated rewards)
	if barRefunded > 0 && barRefunded >= expectedDust {
		ufmt.Printf("[SUCCESS] Dust refund mechanism verified - dust amount (%d) properly included in total refund (%d)!\n", expectedDust, barRefunded)
	} else {
		panic(ufmt.Sprintf("Unexpected refund amount: %d (expected dust: %d)", barRefunded, expectedDust))
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
// [INFO] expected rewardPerSecond: 1286
// [INFO] expected rewardDust: 64007
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
// [INFO] bar balance after ending: 100070440
// [INFO] gns balance after ending: 1000000000
// [RESULT] bar tokens refunded: 70440
// [RESULT] gns tokens refunded: 1000000000
// [SUCCESS] Dust refund mechanism verified - dust amount (64007) properly included in total refund (70440)!
//
// [SUCCESS] Test completed - rewardDust mechanism works correctly!
