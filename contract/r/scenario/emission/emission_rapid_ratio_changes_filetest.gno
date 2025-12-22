// Emission single block precision test
// Scenario: Test emission accuracy with multiple rapid ratio changes
//
// Setup:
// - Period 1: Set 25/25/25/25 ratio (all 4 recipients) and accumulate for 1 block
// - Period 2: Change to 40/30/20/10 ratio and accumulate for 1 block
// - Period 3: Change to 70/15/10/5 ratio and accumulate for 1 block
//
// Expected Behavior:
// - Each period processes exactly 1 block (5 seconds) of emissions
// - Each ratio change correctly distributes previous period
// - All 4 recipients receive correct amounts per their ratios
//
// This verifies that emission calculations are precise even with
// frequent ratio changes at single block granularity.

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
	testSingleBlockPrecision()
}

func testSingleBlockPrecision() {
	println("[SCENARIO] 1. Setup initial 25/25/25/25 distribution ratio")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 2500,
		emission.DEVOPS, 2500,
		emission.COMMUNITY_POOL, 2500,
		emission.GOV_STAKER, 2500,
	)
	println("[INFO] distribution ratio set to 25/25/25/25 (all recipients)")
	println()

	println("[SCENARIO] 2. Set distribution start time")
	now := time.Now().Unix()
	distributionStartTime := now + 1
	emission.SetDistributionStartTime(cross, distributionStartTime)
	println("[INFO] initial distribution: Staker=0, DevOps=0")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 1 block (5 seconds)")
	testing.SkipHeights(1)
	timestampAfterPeriod1 := time.Now().Unix()
	println("[INFO] emissions accumulated without distribution")
	println()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (1 block)", elapsedSeconds1))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond1, elapsedSeconds1, expectedTotalEmission1))
	println()

	println("[SCENARIO] 4. Change distribution ratio to 40/30/20/10")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 4000,
		emission.DEVOPS, 3000,
		emission.COMMUNITY_POOL, 2000,
		emission.GOV_STAKER, 1000,
	)

	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()
	period1Gov := emission.GetDistributedToGovStaker()
	totalPeriod1 := period1Staker + period1Devops + period1Community + period1Gov

	println(ufmt.Sprintf("[INFO] Period 1 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period1Staker, period1Devops, period1Community, period1Gov))
	println("[INFO] expected Staker: 8918378 (25%)")
	println("[INFO] expected DevOps: 8918378 (25%)")
	println("[INFO] expected Community: 8918378 (25%)")
	println("[INFO] expected Gov: 8918378 (25%)")
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker: %d", period1Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 1 DevOps: %d", period1Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Community: %d", period1Community))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Gov: %d", period1Gov))
	println(ufmt.Sprintf("[EXPECTED] Period 1 total: %d", totalPeriod1))
	println()

	println("[SCENARIO] 5. Accumulate 1 more block (Period 2)")
	testing.SkipHeights(1)
	timestampAfterPeriod2 := time.Now().Unix()

	// Calculate emission details for Period 2
	emissionPerSecond2 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod2)
	elapsedSeconds2 := timestampAfterPeriod2 - timestampAfterPeriod1
	expectedTotalEmission2 := emissionPerSecond2 * elapsedSeconds2

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond2))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (1 block)", elapsedSeconds2))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond2, elapsedSeconds2, expectedTotalEmission2))
	println()

	println("[SCENARIO] 6. Change distribution ratio to 70/15/10/5")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000,
		emission.DEVOPS, 1500,
		emission.COMMUNITY_POOL, 1000,
		emission.GOV_STAKER, 500,
	)

	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	totalCommunity := emission.GetDistributedToCommunityPool()
	totalGov := emission.GetDistributedToGovStaker()

	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	period2Community := totalCommunity - period1Community
	period2Gov := totalGov - period1Gov
	totalPeriod2 := period2Staker + period2Devops + period2Community + period2Gov

	println(ufmt.Sprintf("[INFO] Period 2 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period2Staker, period2Devops, period2Community, period2Gov))
	println("[INFO] expected Staker: 14269407 (40%)")
	println("[INFO] expected DevOps: 10702055 (30%)")
	println("[INFO] expected Community: 7134703 (20%)")
	println("[INFO] expected Gov: 3567351 (10%)")
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker: %d", period2Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 2 DevOps: %d", period2Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Community: %d", period2Community))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Gov: %d", period2Gov))
	println(ufmt.Sprintf("[EXPECTED] Period 2 total: %d", totalPeriod2))
	println()

	println("[SCENARIO] 7. Accumulate 1 more block (Period 3)")
	testing.SkipHeights(1)
	timestampAfterPeriod3 := time.Now().Unix()

	// Calculate emission details for Period 3
	emissionPerSecond3 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod3)
	elapsedSeconds3 := timestampAfterPeriod3 - timestampAfterPeriod2
	expectedTotalEmission3 := emissionPerSecond3 * elapsedSeconds3

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond3))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (1 block)", elapsedSeconds3))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond3, elapsedSeconds3, expectedTotalEmission3))
	println()

	emission.MintAndDistributeGns(cross)
	finalStaker := emission.GetDistributedToStaker()
	finalDevops := emission.GetDistributedToDevOps()
	finalCommunity := emission.GetDistributedToCommunityPool()
	finalGov := emission.GetDistributedToGovStaker()

	period3Staker := finalStaker - totalStaker
	period3Devops := finalDevops - totalDevops
	period3Community := finalCommunity - totalCommunity
	period3Gov := finalGov - totalGov
	totalPeriod3 := period3Staker + period3Devops + period3Community + period3Gov

	println(ufmt.Sprintf("[INFO] Period 3 distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		period3Staker, period3Devops, period3Community, period3Gov))
	println("[INFO] expected Staker: 24971461 (70%)")
	println("[INFO] expected DevOps: 5351027 (15%)")
	println("[INFO] expected Community: 3567351 (10%)")
	println("[INFO] expected Gov: 1783675 (5%)")
	println(ufmt.Sprintf("[EXPECTED] Period 3 Staker: %d", period3Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 3 DevOps: %d", period3Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 3 Community: %d", period3Community))
	println(ufmt.Sprintf("[EXPECTED] Period 3 Gov: %d", period3Gov))
	println(ufmt.Sprintf("[EXPECTED] Period 3 total: %d", totalPeriod3))

	println()
	totalDistributed := finalStaker + finalDevops + finalCommunity + finalGov
	println("[INFO] expected total distributed: 107020542")
	println(ufmt.Sprintf("[EXPECTED] Total distributed: %d", totalDistributed))
}

// Output:
// [SCENARIO] 1. Setup initial 25/25/25/25 distribution ratio
// [INFO] distribution ratio set to 25/25/25/25 (all recipients)
//
// [SCENARIO] 2. Set distribution start time
// [INFO] initial distribution: Staker=0, DevOps=0
//
// [SCENARIO] 3. Accumulate emissions for 1 block (5 seconds)
// [INFO] emissions accumulated without distribution
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [SCENARIO] 4. Change distribution ratio to 40/30/20/10
// [INFO] Period 1 distributed: Staker=8918378, DevOps=8918378, Community=8918378, Gov=8918378
// [INFO] expected Staker: 8918378 (25%)
// [INFO] expected DevOps: 8918378 (25%)
// [INFO] expected Community: 8918378 (25%)
// [INFO] expected Gov: 8918378 (25%)
// [EXPECTED] Period 1 Staker: 8918378
// [EXPECTED] Period 1 DevOps: 8918378
// [EXPECTED] Period 1 Community: 8918378
// [EXPECTED] Period 1 Gov: 8918378
// [EXPECTED] Period 1 total: 35673512
//
// [SCENARIO] 5. Accumulate 1 more block (Period 2)
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [SCENARIO] 6. Change distribution ratio to 70/15/10/5
// [INFO] Period 2 distributed: Staker=14269407, DevOps=10702055, Community=7134703, Gov=3567351
// [INFO] expected Staker: 14269407 (40%)
// [INFO] expected DevOps: 10702055 (30%)
// [INFO] expected Community: 7134703 (20%)
// [INFO] expected Gov: 3567351 (10%)
// [EXPECTED] Period 2 Staker: 14269407
// [EXPECTED] Period 2 DevOps: 10702055
// [EXPECTED] Period 2 Community: 7134703
// [EXPECTED] Period 2 Gov: 3567351
// [EXPECTED] Period 2 total: 35673516
//
// [SCENARIO] 7. Accumulate 1 more block (Period 3)
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [INFO] Period 3 distributed: Staker=24971461, DevOps=5351027, Community=3567351, Gov=1783675
// [INFO] expected Staker: 24971461 (70%)
// [INFO] expected DevOps: 5351027 (15%)
// [INFO] expected Community: 3567351 (10%)
// [INFO] expected Gov: 1783675 (5%)
// [EXPECTED] Period 3 Staker: 24971461
// [EXPECTED] Period 3 DevOps: 5351027
// [EXPECTED] Period 3 Community: 3567351
// [EXPECTED] Period 3 Gov: 1783675
// [EXPECTED] Period 3 total: 35673514
//
// [INFO] expected total distributed: 107020542
// [EXPECTED] Total distributed: 107020542
