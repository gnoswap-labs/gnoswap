// Emission zero recipient scenario test
// Scenario: Change some recipients to 0% while others remain active
//
// Setup:
// - Period 1: All recipients get tokens (Staker 40%, DevOps 30%, Community 30%)
// - Accumulate for 15 days
// - Period 2: Change to exclude some recipients (Staker 100%, others 0%)
//
// Expected Behavior:
// - Period 1 emissions distributed to all recipients per their ratios
// - Period 2 emissions go only to active recipients (Staker 100%)
// - Recipients with 0% receive nothing in Period 2

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
	testZeroRecipientScenario()
}

func testZeroRecipientScenario() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[SCENARIO] 2. Period 1 - All recipients active (40% Staker, 30% DevOps, 30% Community)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 4000, // 40%
		emission.DEVOPS, 3000,           // 30%
		emission.COMMUNITY_POOL, 3000,   // 30%
		emission.GOV_STAKER, 0,          // 0%
	)
	println("[INFO] Period 1 ratios: Staker=40%, DevOps=30%, Community=30%")

	println()
	println("[SCENARIO] 3. Skip 15 days (Period 1)")
	testing.SkipHeights(1296000) // 15 days
	println("[INFO] Period 1: 15 days elapsed")

	println()
	println("[SCENARIO] 4. Change to exclude DevOps and Community (Staker 100%)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 10000, // 100%
		emission.DEVOPS, 0,               // 0%
		emission.COMMUNITY_POOL, 0,       // 0%
		emission.GOV_STAKER, 0,           // 0%
	)
	println("[INFO] Period 2 ratios: Staker=100%, DevOps=0%, Community=0%")

	println()
	println("[SCENARIO] 5. Verify Period 1 distributions (all recipients)")
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Period 1: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period1Staker, period1Devops, period1Community, period1Gov))

	// Calculate total
	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov
	println(ufmt.Sprintf("[INFO] Period 1 total distributed: %d", totalPeriod1))

	// Pre-calculated expected values (from Output section)
	expectedStaker1 := int64(18492867641761)
	expectedDevops1 := int64(13869650731320)
	expectedCommunity1 := int64(13869650731320)
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
	stakerDevopsRatio := float64(period1Staker) / float64(period1Devops)
	expectedRatio := 4000.0 / 3000.0
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker/DevOps ratio should be ~%.2f (40/30), got %.2f", expectedRatio, stakerDevopsRatio))
	uassert.True(t, stakerDevopsRatio > expectedRatio*0.99 && stakerDevopsRatio < expectedRatio*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 1 sum should equal total: %d == %d", totalPeriod1, expectedTotal1))
	uassert.Equal(t, expectedTotal1, totalPeriod1)
	println()
	println("[SCENARIO] 6. Skip 15 days (Period 2)")
	testing.SkipHeights(1296000) // 15 days
	println("[INFO] Period 2: 15 days elapsed")

	println()
	println("[SCENARIO] 7. Mint new emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[SCENARIO] 8. Verify Period 2 distributions (only Staker)")
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	totalCommunity := emission.GetDistributedToCommunityPool()
	totalGov := emission.GetDistributedToGovStaker()

	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	period2Community := totalCommunity - period1Community
	period2Gov := totalGov - period1Gov

	println(ufmt.Sprintf("[INFO] Period 2: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period2Staker, period2Devops, period2Community, period2Gov))

	// Calculate total
	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov
	println(ufmt.Sprintf("[INFO] Period 2 total distributed: %d", totalPeriod2))

	// Pre-calculated expected values (from Output section)
	expectedStaker2 := int64(46232875440002)
	expectedDevops2 := int64(0)
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

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Period 2 sum should equal total: %d == %d", totalPeriod2, expectedTotal2))
	uassert.Equal(t, expectedTotal2, totalPeriod2)
	println()
}

// Output:
// [SCENARIO] 1. Set distribution start time
// [INFO] Distribution start time set
//
// [SCENARIO] 2. Period 1 - All recipients active (40% Staker, 30% DevOps, 30% Community)
// [INFO] Period 1 ratios: Staker=40%, DevOps=30%, Community=30%
//
// [SCENARIO] 3. Skip 15 days (Period 1)
// [INFO] Period 1: 15 days elapsed
//
// [SCENARIO] 4. Change to exclude DevOps and Community (Staker 100%)
// [INFO] Period 2 ratios: Staker=100%, DevOps=0%, Community=0%
//
// [SCENARIO] 5. Verify Period 1 distributions (all recipients)
// [INFO] Period 1: Staker=18492867641761, DevOps=13869650731320, Community=13869650731320, Gov=0
// [INFO] Period 1 total distributed: 46232169104401
// [EXPECTED] Period 1 Staker should be 18492867641761, got 18492867641761
// [EXPECTED] Period 1 DevOps should be 13869650731320, got 13869650731320
// [EXPECTED] Period 1 Community should be 13869650731320, got 13869650731320
// [EXPECTED] Period 1 Gov should be 0, got 0
// [EXPECTED] Period 1 Staker/DevOps ratio should be ~1.33 (40/30), got 1.33
// [EXPECTED] Period 1 sum should equal total: 46232169104401 == 46232169104401
//
// [SCENARIO] 6. Skip 15 days (Period 2)
// [INFO] Period 2: 15 days elapsed
//
// [SCENARIO] 7. Mint new emissions
// [INFO] MintAndDistributeGns called
//
// [SCENARIO] 8. Verify Period 2 distributions (only Staker)
// [INFO] Period 2: Staker=46232875440002, DevOps=0, Community=0, Gov=0
// [INFO] Period 2 total distributed: 46232875440002
// [EXPECTED] Period 2 Staker should be 46232875440002, got 46232875440002
// [EXPECTED] Period 2 DevOps should be 0, got 0
// [EXPECTED] Period 2 Community should be 0, got 0
// [EXPECTED] Period 2 Gov should be 0, got 0
// [EXPECTED] Period 2 sum should equal total: 46232875440002 == 46232875440002
//
