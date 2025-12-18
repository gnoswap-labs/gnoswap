// Emission complex ratio changes scenario test
// Scenario: Complex governance adjustments with all 4 recipients active
//
// Setup:
// - Period 1: Staker 40%, DevOps 30%, Community 20%, Gov 10% - accumulate 10 days
// - Period 2: Staker 50%, DevOps 25%, Community 15%, Gov 10% - accumulate 10 days
// - Period 3: Staker 60%, DevOps 20%, Community 10%, Gov 10%
//
// Expected Behavior:
// - Period 1: All 4 recipients receive emissions at 40/30/20/10 ratios
// - Period 2: All 4 recipients receive emissions at 50/25/15/10 ratios
// - Each period maintains its own ratio independently
//
// This tests realistic complex governance with all recipients participating
// and their allocations changing over time.

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

func main() {
	testComplexRatioChanges()
}

func testComplexRatioChanges() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	distributionStartTime := now + 1
	emission.SetDistributionStartTime(cross, distributionStartTime)
	println()

	println("[SCENARIO] 2. Set Period 1 ratio (40/30/20/10)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 4000,   // 40%
		emission.DEVOPS, 3000,             // 30%
		emission.COMMUNITY_POOL, 2000,     // 20%
		emission.GOV_STAKER, 1000,         // 10%
	)
	println("[INFO] period 1 ratio: Staker 40%, DevOps 30%, Community 20%, Gov 10%")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 10 days (Period 1)")
	testing.SkipHeights(864000)
	timestampAfterPeriod1 := time.Now().Unix()
	println("[INFO] period 1: 10 days elapsed")
	println()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (from distribution start time, inclusive range)", elapsedSeconds1))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond1, elapsedSeconds1, expectedTotalEmission1))
	println()

	println("[SCENARIO] 4. Change to Period 2 ratio (50/25/15/10)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000,   // 50%
		emission.DEVOPS, 2500,             // 25%
		emission.COMMUNITY_POOL, 1500,     // 15%
		emission.GOV_STAKER, 1000,         // 10%
	)

	// Get all recipients for Period 1
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Period 1 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period1Staker, period1Devops, period1Community, period1Gov))

	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov
	println(ufmt.Sprintf("[INFO] Period 1 total distributed: %d", totalPeriod1))

	expectedStaker1 := int64(12328766784000)
	expectedDevops1 := int64(9246575088000)
	expectedCommunity1 := int64(6164383392000)
	expectedGov1 := int64(3082191696000)
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

	// Verify ratios between recipients
	stakerDevopsRatio := float64(period1Staker) / float64(period1Devops)
	stakerCommunityRatio := float64(period1Staker) / float64(period1Community)
	stakerGovRatio := float64(period1Staker) / float64(period1Gov)

	expectedStakerDevops := 4000.0 / 3000.0       // 1.33
	expectedStakerCommunity := 4000.0 / 2000.0    // 2.00
	expectedStakerGov := 4000.0 / 1000.0          // 4.00

	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker/DevOps ratio should be ~%.2f (40/30), got %.2f", expectedStakerDevops, stakerDevopsRatio))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker/Community ratio should be ~%.2f (40/20), got %.2f", expectedStakerCommunity, stakerCommunityRatio))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker/Gov ratio should be ~%.2f (40/10), got %.2f", expectedStakerGov, stakerGovRatio))

	uassert.True(t, stakerDevopsRatio > expectedStakerDevops*0.99 && stakerDevopsRatio < expectedStakerDevops*1.01)
	uassert.True(t, stakerCommunityRatio > expectedStakerCommunity*0.99 && stakerCommunityRatio < expectedStakerCommunity*1.01)
	uassert.True(t, stakerGovRatio > expectedStakerGov*0.99 && stakerGovRatio < expectedStakerGov*1.01)

	// Verify sum equals total
	println(ufmt.Sprintf("[EXPECTED] Period 1 sum should equal total: %d == %d", totalPeriod1, expectedTotal1))
	uassert.Equal(t, expectedTotal1, totalPeriod1)
	println()

	println("[SCENARIO] 5. Accumulate emissions for 10 days (Period 2)")
	testing.SkipHeights(864000)
	timestampAfterPeriod2 := time.Now().Unix()
	println("[INFO] period 2: 10 days elapsed")
	println()

	// Calculate emission details for Period 2
	emissionPerSecond2 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod2)
	elapsedSeconds2 := timestampAfterPeriod2 - timestampAfterPeriod1
	expectedTotalEmission2 := emissionPerSecond2 * elapsedSeconds2

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond2))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (10 days, subsequent minting)", elapsedSeconds2))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond2, elapsedSeconds2, expectedTotalEmission2))
	println()

	println("[SCENARIO] 6. Change to Period 3 ratio (60/20/10/10)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 6000,   // 60%
		emission.DEVOPS, 2000,             // 20%
		emission.COMMUNITY_POOL, 1000,     // 10%
		emission.GOV_STAKER, 1000,         // 10%
	)

	// Get all recipients for total (Period 1 + Period 2)
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	totalCommunity := emission.GetDistributedToCommunityPool()
	totalGov := emission.GetDistributedToGovStaker()

	// Calculate Period 2 amounts
	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	period2Community := totalCommunity - period1Community
	period2Gov := totalGov - period1Gov

	println(ufmt.Sprintf("[INFO] Period 2 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period2Staker, period2Devops, period2Community, period2Gov))

	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov
	println(ufmt.Sprintf("[INFO] Period 2 total distributed: %d", totalPeriod2))

	expectedStaker2 := int64(15410958480000)
	expectedDevops2 := int64(7705479240000)
	expectedCommunity2 := int64(4623287544000)
	expectedGov2 := int64(3082191696000)
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

	// Verify ratios between recipients for Period 2
	staker2DevopsRatio := float64(period2Staker) / float64(period2Devops)
	staker2CommunityRatio := float64(period2Staker) / float64(period2Community)
	staker2GovRatio := float64(period2Staker) / float64(period2Gov)

	expectedStaker2Devops := 5000.0 / 2500.0      // 2.00
	expectedStaker2Community := 5000.0 / 1500.0   // 3.33
	expectedStaker2Gov := 5000.0 / 1000.0         // 5.00

	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker/DevOps ratio should be ~%.2f (50/25), got %.2f", expectedStaker2Devops, staker2DevopsRatio))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker/Community ratio should be ~%.2f (50/15), got %.2f", expectedStaker2Community, staker2CommunityRatio))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker/Gov ratio should be ~%.2f (50/10), got %.2f", expectedStaker2Gov, staker2GovRatio))

	uassert.True(t, staker2DevopsRatio > expectedStaker2Devops*0.99 && staker2DevopsRatio < expectedStaker2Devops*1.01)
	uassert.True(t, staker2CommunityRatio > expectedStaker2Community*0.99 && staker2CommunityRatio < expectedStaker2Community*1.01)
	uassert.True(t, staker2GovRatio > expectedStaker2Gov*0.99 && staker2GovRatio < expectedStaker2Gov*1.01)

	// Verify sum equals total
	println(ufmt.Sprintf("[EXPECTED] Period 2 sum should equal total: %d == %d", totalPeriod2, expectedTotal2))
	uassert.Equal(t, expectedTotal2, totalPeriod2)

	// Verify overall distribution across both periods
	overallTotal := totalStaker + totalDevops + totalCommunity + totalGov
	expectedOverallTotal := expectedTotal1 + expectedTotal2
	println(ufmt.Sprintf("[EXPECTED] Overall total should be %d, got %d", expectedOverallTotal, overallTotal))
	uassert.Equal(t, expectedOverallTotal, overallTotal)
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Set Period 1 ratio (40/30/20/10)
// [INFO] period 1 ratio: Staker 40%, DevOps 30%, Community 20%, Gov 10%
//
// [SCENARIO] 3. Accumulate emissions for 10 days (Period 1)
// [INFO] period 1: 10 days elapsed
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (from distribution start time, inclusive range)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 4. Change to Period 2 ratio (50/25/15/10)
// [INFO] Period 1 distributed: Staker=12328766784000, DevOps=9246575088000, Community=6164383392000, Gov=3082191696000
// [INFO] Period 1 total distributed: 30821916960000
// [EXPECTED] Period 1 Staker should be 12328766784000, got 12328766784000
// [EXPECTED] Period 1 DevOps should be 9246575088000, got 9246575088000
// [EXPECTED] Period 1 Community should be 6164383392000, got 6164383392000
// [EXPECTED] Period 1 Gov should be 3082191696000, got 3082191696000
// [EXPECTED] Period 1 Staker/DevOps ratio should be ~1.33 (40/30), got 1.33
// [EXPECTED] Period 1 Staker/Community ratio should be ~2.00 (40/20), got 2.00
// [EXPECTED] Period 1 Staker/Gov ratio should be ~4.00 (40/10), got 4.00
// [EXPECTED] Period 1 sum should equal total: 30821916960000 == 30821916960000
//
// [SCENARIO] 5. Accumulate emissions for 10 days (Period 2)
// [INFO] period 2: 10 days elapsed
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (10 days, subsequent minting)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 6. Change to Period 3 ratio (60/20/10/10)
// [INFO] Period 2 distributed: Staker=15410958480000, DevOps=7705479240000, Community=4623287544000, Gov=3082191696000
// [INFO] Period 2 total distributed: 30821916960000
// [EXPECTED] Period 2 Staker should be 15410958480000, got 15410958480000
// [EXPECTED] Period 2 DevOps should be 7705479240000, got 7705479240000
// [EXPECTED] Period 2 Community should be 4623287544000, got 4623287544000
// [EXPECTED] Period 2 Gov should be 3082191696000, got 3082191696000
// [EXPECTED] Period 2 Staker/DevOps ratio should be ~2.00 (50/25), got 2.00
// [EXPECTED] Period 2 Staker/Community ratio should be ~3.33 (50/15), got 3.33
// [EXPECTED] Period 2 Staker/Gov ratio should be ~5.00 (50/10), got 5.00
// [EXPECTED] Period 2 sum should equal total: 30821916960000 == 30821916960000
// [EXPECTED] Overall total should be 61643833920000, got 61643833920000
