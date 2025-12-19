// Emission complex ratio changes scenario test
// Scenario: Complex governance adjustments with all 4 recipients active
//
// Setup:
// - Period 1: Staker 40%, DevOps 30%, Community 20%, Gov 10% - accumulate 50 days
// - Period 2: Staker 50%, DevOps 25%, Community 15%, Gov 10% - accumulate 50 days
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

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
)

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
		emission.LIQUIDITY_STAKER, 4000, // 40%
		emission.DEVOPS, 3000, // 30%
		emission.COMMUNITY_POOL, 2000, // 20%
		emission.GOV_STAKER, 1000, // 10%
	)
	println("[INFO] period 1 ratio: Staker 40%, DevOps 30%, Community 20%, Gov 10%")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 50 days (Period 1)")
	testing.SkipHeights(864000)
	timestampAfterPeriod1 := time.Now().Unix()
	println("[INFO] period 1: 50 days elapsed")
	println()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (50 days)", elapsedSeconds1))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond1, elapsedSeconds1, expectedTotalEmission1))
	println()

	println("[SCENARIO] 4. Change to Period 2 ratio (50/25/15/10)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 2500, // 25%
		emission.COMMUNITY_POOL, 1500, // 15%
		emission.GOV_STAKER, 1000, // 10%
	)

	println("[INFO] Period 1 distributed: Staker=12328766784000, DevOps=9246575088000, Community=6164383392000, Gov=3082191696000")
	println("[INFO] Period 1 total distributed: 30821916960000")

	// Get all recipients for Period 1
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()
	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov

	println("[INFO] expected Staker: 12328766784000 (40%)")
	println("[INFO] expected DevOps: 9246575088000 (30%)")
	println("[INFO] expected Community: 6164383392000 (20%)")
	println("[INFO] expected Gov: 3082191696000 (10%)")
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker: %d", period1Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 1 DevOps: %d", period1Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Community: %d", period1Community))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Gov: %d", period1Gov))
	println(ufmt.Sprintf("[EXPECTED] Period 1 total: %d", totalPeriod1))
	println()

	println("[SCENARIO] 5. Accumulate emissions for 50 days (Period 2)")
	testing.SkipHeights(864000)
	timestampAfterPeriod2 := time.Now().Unix()
	println("[INFO] period 2: 50 days elapsed")
	println()

	// Calculate emission details for Period 2
	emissionPerSecond2 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod2)
	elapsedSeconds2 := timestampAfterPeriod2 - timestampAfterPeriod1
	expectedTotalEmission2 := emissionPerSecond2 * elapsedSeconds2

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond2))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (50 days)", elapsedSeconds2))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond2, elapsedSeconds2, expectedTotalEmission2))
	println()

	println("[SCENARIO] 6. Change to Period 3 ratio (60/20/10/10)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 6000, // 60%
		emission.DEVOPS, 2000, // 20%
		emission.COMMUNITY_POOL, 1000, // 10%
		emission.GOV_STAKER, 1000, // 10%
	)

	// Get all recipients for total (Period 1 + Period 2)
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	totalCommunity := emission.GetDistributedToCommunityPool()
	totalGov := emission.GetDistributedToGovStaker()

	println("[INFO] Period 2 distributed: Staker=15410958480000, DevOps=7705479240000, Community=4623287544000, Gov=3082191696000")
	println("[INFO] Period 2 total distributed: 30821916960000")

	// Calculate Period 2 amounts
	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	period2Community := totalCommunity - period1Community
	period2Gov := totalGov - period1Gov
	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov

	println("[INFO] expected Staker: 15410958480000 (50%)")
	println("[INFO] expected DevOps: 7705479240000 (25%)")
	println("[INFO] expected Community: 4623287544000 (15%)")
	println("[INFO] expected Gov: 3082191696000 (10%)")
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker: %d", period2Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 2 DevOps: %d", period2Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Community: %d", period2Community))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Gov: %d", period2Gov))
	println(ufmt.Sprintf("[EXPECTED] Period 2 total: %d", totalPeriod2))

	println()
	overallTotal := totalStaker + totalDevops + totalCommunity + totalGov
	println("[INFO] expected total distributed: 61643833920000")
	println(ufmt.Sprintf("[EXPECTED] Total distributed: %d", overallTotal))
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Set Period 1 ratio (40/30/20/10)
// [INFO] period 1 ratio: Staker 40%, DevOps 30%, Community 20%, Gov 10%
//
// [SCENARIO] 3. Accumulate emissions for 50 days (Period 1)
// [INFO] period 1: 50 days elapsed
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (50 days)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 4. Change to Period 2 ratio (50/25/15/10)
// [INFO] Period 1 distributed: Staker=12328766784000, DevOps=9246575088000, Community=6164383392000, Gov=3082191696000
// [INFO] Period 1 total distributed: 30821916960000
// [INFO] expected Staker: 12328766784000 (40%)
// [INFO] expected DevOps: 9246575088000 (30%)
// [INFO] expected Community: 6164383392000 (20%)
// [INFO] expected Gov: 3082191696000 (10%)
// [EXPECTED] Period 1 Staker: 12328766784000
// [EXPECTED] Period 1 DevOps: 9246575088000
// [EXPECTED] Period 1 Community: 6164383392000
// [EXPECTED] Period 1 Gov: 3082191696000
// [EXPECTED] Period 1 total: 30821916960000
//
// [SCENARIO] 5. Accumulate emissions for 50 days (Period 2)
// [INFO] period 2: 50 days elapsed
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (50 days)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 6. Change to Period 3 ratio (60/20/10/10)
// [INFO] Period 2 distributed: Staker=15410958480000, DevOps=7705479240000, Community=4623287544000, Gov=3082191696000
// [INFO] Period 2 total distributed: 30821916960000
// [INFO] expected Staker: 15410958480000 (50%)
// [INFO] expected DevOps: 7705479240000 (25%)
// [INFO] expected Community: 4623287544000 (15%)
// [INFO] expected Gov: 3082191696000 (10%)
// [EXPECTED] Period 2 Staker: 15410958480000
// [EXPECTED] Period 2 DevOps: 7705479240000
// [EXPECTED] Period 2 Community: 4623287544000
// [EXPECTED] Period 2 Gov: 3082191696000
// [EXPECTED] Period 2 total: 30821916960000
//
// [INFO] expected total distributed: 61643833920000
// [EXPECTED] Total distributed: 61643833920000
