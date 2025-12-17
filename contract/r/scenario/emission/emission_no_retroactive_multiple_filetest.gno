// Emission multiple ratio changes scenario test
// Scenario: Multiple distribution ratio changes over time
//
// Setup:
// - Period 1 (20 days): 70% Liquidity Staker, 30% DevOps
// - Period 2 (20 days): 60% Liquidity Staker, 40% DevOps
// - Period 3 (ongoing): 50% Liquidity Staker, 50% DevOps
//
// Expected Behavior:
// - Period 1 emissions should be distributed at 70/30 ratio
// - Period 2 emissions should be distributed at 60/40 ratio
// - Each period's emissions use their corresponding ratios, no retroactive effects

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
	testMultipleRatioChanges()
}

func testMultipleRatioChanges() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println()

	println("[SCENARIO] 2. Set Period 1 ratio (70/30)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000,
		emission.DEVOPS, 3000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] period 1 ratio set to 70/30")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 20 days (Period 1)")
	testing.SkipHeights(1728000)
	println("[INFO] period 1: 20 days elapsed")
	println()

	println("[SCENARIO] 4. Change to 60/40 ratio (Period 2 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 6000,
		emission.DEVOPS, 4000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)

	// Get all recipients for Period 1
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Period 1 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period1Staker, period1Devops, period1Community, period1Gov))

	// Calculate total
	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov
	println(ufmt.Sprintf("[INFO] Period 1 total distributed: %d", totalPeriod1))

	// Pre-calculated expected values (from Output section)
	expectedStaker1 := int64(43150189309082)
	expectedDevops1 := int64(18492938275320)
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
	expectedRatio1 := 7000.0 / 3000.0
	println(ufmt.Sprintf("[EXPECTED] Period 1 ratio should be ~%.2f (70/30), got %.2f", expectedRatio1, ratio1))
	uassert.True(t, ratio1 > expectedRatio1*0.99 && ratio1 < expectedRatio1*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 1 sum should equal total: %d == %d", totalPeriod1, expectedTotal1))
	uassert.Equal(t, expectedTotal1, totalPeriod1)
	println()

	println("[SCENARIO] 5. Accumulate emissions for 20 days (Period 2)")
	testing.SkipHeights(1728000)
	println("[INFO] period 2: 20 days elapsed")
	println()

	println("[SCENARIO] 6. Change to 50/50 ratio (Period 3 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000,
		emission.DEVOPS, 5000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
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

	// Calculate Period 2 total
	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov
	println(ufmt.Sprintf("[INFO] Period 2 total distributed: %d", totalPeriod2))

	// Pre-calculated expected values (from Output section)
	expectedStaker2 := int64(36986300352000)
	expectedDevops2 := int64(24657533568000)
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
	expectedRatio2 := 6000.0 / 4000.0
	println(ufmt.Sprintf("[EXPECTED] Period 2 ratio should be ~%.2f (60/40), got %.2f", expectedRatio2, ratio2))
	uassert.True(t, ratio2 > expectedRatio2*0.99 && ratio2 < expectedRatio2*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 2 sum should equal total: %d == %d", totalPeriod2, expectedTotal2))
	uassert.Equal(t, expectedTotal2, totalPeriod2)
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Set Period 1 ratio (70/30)
// [INFO] period 1 ratio set to 70/30
//
// [SCENARIO] 3. Accumulate emissions for 20 days (Period 1)
// [INFO] period 1: 20 days elapsed
//
// [SCENARIO] 4. Change to 60/40 ratio (Period 2 begins)
// [INFO] Period 1 distributed: Staker=43150189309082, DevOps=18492938275320, Community=0, Gov=0
// [INFO] Period 1 total distributed: 61643127584402
// [EXPECTED] Period 1 Staker should be 43150189309082, got 43150189309082
// [EXPECTED] Period 1 DevOps should be 18492938275320, got 18492938275320
// [EXPECTED] Period 1 Community should be 0, got 0
// [EXPECTED] Period 1 Gov should be 0, got 0
// [EXPECTED] Period 1 ratio should be ~2.33 (70/30), got 2.33
// [EXPECTED] Period 1 sum should equal total: 61643127584402 == 61643127584402
//
// [SCENARIO] 5. Accumulate emissions for 20 days (Period 2)
// [INFO] period 2: 20 days elapsed
//
// [SCENARIO] 6. Change to 50/50 ratio (Period 3 begins)
// [INFO] Period 2 distributed: Staker=36986300352000, DevOps=24657533568000, Community=0, Gov=0
// [INFO] Period 2 total distributed: 61643833920000
// [EXPECTED] Period 2 Staker should be 36986300352000, got 36986300352000
// [EXPECTED] Period 2 DevOps should be 24657533568000, got 24657533568000
// [EXPECTED] Period 2 Community should be 0, got 0
// [EXPECTED] Period 2 Gov should be 0, got 0
// [EXPECTED] Period 2 ratio should be ~1.50 (60/40), got 1.50
// [EXPECTED] Period 2 sum should equal total: 61643833920000 == 61643833920000
