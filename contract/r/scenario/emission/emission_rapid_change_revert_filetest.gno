// Emission rapid ratio change and revert scenario test
// Scenario: Change ratio then immediately revert to original
//
// Setup:
// - Initial ratio: 50/50
// - Accumulate for 10 days
// - Change to 90/10
// - Immediately revert to 50/50
// - Accumulate for another 10 days
//
// Expected Behavior:
// - First 10 days distributed at 50/50
// - Brief 90/10 period should distribute accumulated at 50/50
// - Next 10 days distributed at 50/50
// - Overall effect: all emissions at 50/50 (90/10 had no effect)

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

func main() {
	testRapidChangeAndRevert()
}

func testRapidChangeAndRevert() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[SCENARIO] 2. Set initial ratio to 50/50")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Initial ratio: 50/50")

	println()
	println("[SCENARIO] 3. Skip 10 days (Period 1)")
	testing.SkipHeights(864000) // 10 days
	println("[INFO] Period 1: 10 days elapsed at 50/50")

	println()
	println("[SCENARIO] 4. Temporarily change to 90/10")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 9000, // 90%
		emission.DEVOPS, 1000,           // 10%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Changed to 90/10")

	println()
	println("[SCENARIO] 5. Verify Period 1 was distributed at 50/50")
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] After ratio change: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period1Staker, period1Devops, period1Community, period1Gov))

	// Calculate total
	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov
	println(ufmt.Sprintf("[INFO] Period 1 total distributed: %d", totalPeriod1))

	// Pre-calculated expected values (from Output section)
	expectedStaker1 := int64(15410605312201)
	expectedDevops1 := int64(15410605312201)
	expectedCommunity1 := int64(0)
	expectedGov1 := int64(0)
	expectedTotal1 := expectedStaker1 + expectedDevops1 + expectedCommunity1 + expectedGov1

	// Exact assertions
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker should be %d, got %d", expectedStaker1, period1Staker))
	uassert.Equal(t, expectedStaker1, period1Staker)

	println(ufmt.Sprintf("[EXPECTED] Period 1 DevOps should be %d, got %d", expectedDevops1, period1Devops))
	uassert.Equal(t, expectedDevops1, period1Devops)

	println(ufmt.Sprintf("[EXPECTED] Period 1 Community should be %d, got %d", expectedCommunity1, period1Community))
	uassert.Equal(t, expectedCommunity1, period1Community)

	println(ufmt.Sprintf("[EXPECTED] Period 1 Gov should be %d, got %d", expectedGov1, period1Gov))
	uassert.Equal(t, expectedGov1, period1Gov)

	// Ratio verification (tighter tolerance)
	ratio1 := float64(period1Staker) / float64(period1Devops)
	expectedRatio1 := 1.0
	println(ufmt.Sprintf("[EXPECTED] Period 1 ratio should be ~%.2f (50/50), got %.2f", expectedRatio1, ratio1))
	uassert.True(t, ratio1 > expectedRatio1*0.99 && ratio1 < expectedRatio1*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 1 sum should equal total: %d == %d", totalPeriod1, expectedTotal1))
	uassert.Equal(t, expectedTotal1, totalPeriod1)
	println()
	println("[SCENARIO] 6. Immediately revert to 50/50")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Reverted to 50/50")

	println()
	println("[SCENARIO] 7. Verify no additional distribution (90/10 period was empty)")
	revertStaker := emission.GetDistributedToStaker()
	revertDevops := emission.GetDistributedToDevOps()

	uassert.Equal(t, period1Staker, revertStaker)
	uassert.Equal(t, period1Devops, revertDevops)
	println("[INFO] No change in distributions (90/10 had no accumulated emissions)")
	println()
	println("[SCENARIO] 8. Skip another 10 days (Period 2)")
	testing.SkipHeights(864000) // 10 days
	println("[INFO] Period 2: 10 days elapsed at 50/50")

	println()
	println("[SCENARIO] 9. Mint final emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[SCENARIO] 10. Verify Period 2 also distributed at 50/50")
	finalStaker := emission.GetDistributedToStaker()
	finalDevops := emission.GetDistributedToDevOps()
	finalCommunity := emission.GetDistributedToCommunityPool()
	finalGov := emission.GetDistributedToGovStaker()

	period2Staker := finalStaker - revertStaker
	period2Devops := finalDevops - revertDevops
	period2Community := finalCommunity - period1Community
	period2Gov := finalGov - period1Gov

	println(ufmt.Sprintf("[INFO] Period 2: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period2Staker, period2Devops, period2Community, period2Gov))

	// Calculate total
	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov
	println(ufmt.Sprintf("[INFO] Period 2 total distributed: %d", totalPeriod2))

	// Pre-calculated expected values (from Output section)
	expectedStaker2 := int64(15410958480000)
	expectedDevops2 := int64(15410958480000)
	expectedCommunity2 := int64(0)
	expectedGov2 := int64(0)
	expectedTotal2 := expectedStaker2 + expectedDevops2 + expectedCommunity2 + expectedGov2

	// Exact assertions
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker should be %d, got %d", expectedStaker2, period2Staker))
	uassert.Equal(t, expectedStaker2, period2Staker)

	println(ufmt.Sprintf("[EXPECTED] Period 2 DevOps should be %d, got %d", expectedDevops2, period2Devops))
	uassert.Equal(t, expectedDevops2, period2Devops)

	println(ufmt.Sprintf("[EXPECTED] Period 2 Community should be %d, got %d", expectedCommunity2, period2Community))
	uassert.Equal(t, expectedCommunity2, period2Community)

	println(ufmt.Sprintf("[EXPECTED] Period 2 Gov should be %d, got %d", expectedGov2, period2Gov))
	uassert.Equal(t, expectedGov2, period2Gov)

	// Ratio verification (tighter tolerance)
	ratio2 := float64(period2Staker) / float64(period2Devops)
	expectedRatio2 := 1.0
	println(ufmt.Sprintf("[EXPECTED] Period 2 ratio should be ~%.2f (50/50), got %.2f", expectedRatio2, ratio2))
	uassert.True(t, ratio2 > expectedRatio2*0.99 && ratio2 < expectedRatio2*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 2 sum should equal total: %d == %d", totalPeriod2, expectedTotal2))
	uassert.Equal(t, expectedTotal2, totalPeriod2)

	println()
	println("[SCENARIO] 11. Verify overall distribution")
	overallTotal := finalStaker + finalDevops + finalCommunity + finalGov
	println(ufmt.Sprintf("[INFO] Overall total distributed: %d", overallTotal))

	// Pre-calculated expected overall values
	expectedOverallStaker := expectedStaker1 + expectedStaker2
	expectedOverallDevops := expectedDevops1 + expectedDevops2
	expectedOverallCommunity := expectedCommunity1 + expectedCommunity2
	expectedOverallGov := expectedGov1 + expectedGov2
	expectedOverallTotal := expectedOverallStaker + expectedOverallDevops + expectedOverallCommunity + expectedOverallGov

	// Exact assertions
	println(ufmt.Sprintf("[EXPECTED] Overall Staker should be %d, got %d", expectedOverallStaker, finalStaker))
	uassert.Equal(t, expectedOverallStaker, finalStaker)

	println(ufmt.Sprintf("[EXPECTED] Overall DevOps should be %d, got %d", expectedOverallDevops, finalDevops))
	uassert.Equal(t, expectedOverallDevops, finalDevops)

	println(ufmt.Sprintf("[EXPECTED] Overall Community should be %d, got %d", expectedOverallCommunity, finalCommunity))
	uassert.Equal(t, expectedOverallCommunity, finalCommunity)

	println(ufmt.Sprintf("[EXPECTED] Overall Gov should be %d, got %d", expectedOverallGov, finalGov))
	uassert.Equal(t, expectedOverallGov, finalGov)

	// Overall ratio verification
	overallRatio := float64(finalStaker) / float64(finalDevops)
	expectedOverallRatio := 1.0
	println(ufmt.Sprintf("[EXPECTED] Overall ratio should be ~%.2f (50/50), got %.2f", expectedOverallRatio, overallRatio))
	uassert.True(t, overallRatio > expectedOverallRatio*0.99 && overallRatio < expectedOverallRatio*1.01)

	// Overall sum verification
	println(ufmt.Sprintf("[EXPECTED] Overall sum should equal total: %d == %d", overallTotal, expectedOverallTotal))
	uassert.Equal(t, expectedOverallTotal, overallTotal)
	println()
}

// Output:
// [SCENARIO] 1. Set distribution start time
// [INFO] Distribution start time set
//
// [SCENARIO] 2. Set initial ratio to 50/50
// [INFO] Initial ratio: 50/50
//
// [SCENARIO] 3. Skip 10 days (Period 1)
// [INFO] Period 1: 10 days elapsed at 50/50
//
// [SCENARIO] 4. Temporarily change to 90/10
// [INFO] Changed to 90/10
//
// [SCENARIO] 5. Verify Period 1 was distributed at 50/50
// [INFO] After ratio change: Staker=15410605312201, DevOps=15410605312201, Community=0, Gov=0
// [INFO] Period 1 total distributed: 30821210624402
// [EXPECTED] Period 1 Staker should be 15410605312201, got 15410605312201
// [EXPECTED] Period 1 DevOps should be 15410605312201, got 15410605312201
// [EXPECTED] Period 1 Community should be 0, got 0
// [EXPECTED] Period 1 Gov should be 0, got 0
// [EXPECTED] Period 1 ratio should be ~1.00 (50/50), got 1.00
// [EXPECTED] Period 1 sum should equal total: 30821210624402 == 30821210624402
//
// [SCENARIO] 6. Immediately revert to 50/50
// [INFO] Reverted to 50/50
//
// [SCENARIO] 7. Verify no additional distribution (90/10 period was empty)
// [INFO] No change in distributions (90/10 had no accumulated emissions)
//
// [SCENARIO] 8. Skip another 10 days (Period 2)
// [INFO] Period 2: 10 days elapsed at 50/50
//
// [SCENARIO] 9. Mint final emissions
// [INFO] MintAndDistributeGns called
//
// [SCENARIO] 10. Verify Period 2 also distributed at 50/50
// [INFO] Period 2: Staker=15410958480000, DevOps=15410958480000, Community=0, Gov=0
// [INFO] Period 2 total distributed: 30821916960000
// [EXPECTED] Period 2 Staker should be 15410958480000, got 15410958480000
// [EXPECTED] Period 2 DevOps should be 15410958480000, got 15410958480000
// [EXPECTED] Period 2 Community should be 0, got 0
// [EXPECTED] Period 2 Gov should be 0, got 0
// [EXPECTED] Period 2 ratio should be ~1.00 (50/50), got 1.00
// [EXPECTED] Period 2 sum should equal total: 30821916960000 == 30821916960000
//
// [SCENARIO] 11. Verify overall distribution
// [INFO] Overall total distributed: 61643127584402
// [EXPECTED] Overall Staker should be 30821563792201, got 30821563792201
// [EXPECTED] Overall DevOps should be 30821563792201, got 30821563792201
// [EXPECTED] Overall Community should be 0, got 0
// [EXPECTED] Overall Gov should be 0, got 0
// [EXPECTED] Overall ratio should be ~1.00 (50/50), got 1.00
// [EXPECTED] Overall sum should equal total: 61643127584402 == 61643127584402
//
