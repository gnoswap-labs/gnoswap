// Emission explicit mint distribution test
// Scenario: Test distribution by explicitly calling MintAndDistributeGns
//
// Setup:
// - Period 1: 70/25/5/0 ratio, 1 block, explicit mint call
// - Period 2: 0/50/0/50 ratio, 1 block, explicit mint call
// - Period 3: 30/30/30/10 ratio, 1 block, explicit mint call
//
// Expected Behavior:
// - Each period: ChangeDistributionPct → skip 1 block → MintAndDistributeGns
// - Distribution occurs on explicit mint call, not during ratio change
// - Each period receives correct amounts per their ratios
//
// This verifies that explicit MintAndDistributeGns calls correctly
// distribute accumulated emissions with the current ratio.

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
	testExplicitMintDistribution()
}

func testExplicitMintDistribution() {
	println("[SCENARIO] 1. Setup initial 70/25/5/0 distribution ratio")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000,
		emission.DEVOPS, 2500,
		emission.COMMUNITY_POOL, 500,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] distribution ratio set to 70/25/5/0 (Staker/DevOps/Pool/xGNS)")
	println()

	println("[SCENARIO] 2. Set distribution start time")
	now := time.Now().Unix()
	distributionStartTime := now + 1
	emission.SetDistributionStartTime(cross, distributionStartTime)
	println("[INFO] initial distribution: all recipients = 0")
	println()

	println("[SCENARIO] 3. Skip 1 block and mint (Period 1)")
	testing.SkipHeights(1)
	timestampAfterPeriod1 := time.Now().Unix()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (1 block)", elapsedSeconds1))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond1, elapsedSeconds1, expectedTotalEmission1))
	println()

	emission.MintAndDistributeGns(cross)
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Pool := emission.GetDistributedToCommunityPool()
	period1XGns := emission.GetDistributedToGovStaker()
	totalPeriod1 := period1Staker + period1Devops + period1Pool + period1XGns

	println(ufmt.Sprintf("[INFO] Period 1 distributed: Staker=%d, DevOps=%d, Pool=%d, xGNS=%d",
		period1Staker, period1Devops, period1Pool, period1XGns))
	println("[INFO] expected Staker: 24971460 (70%)")
	println("[INFO] expected DevOps: 8918378 (25%)")
	println("[INFO] expected Community: 1783675 (5%)")
	println("[INFO] expected xGNS: 0 (0%)")
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker: %d", period1Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 1 DevOps: %d", period1Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 1 Pool: %d", period1Pool))
	println(ufmt.Sprintf("[EXPECTED] Period 1 xGNS: %d", period1XGns))
	println(ufmt.Sprintf("[EXPECTED] Period 1 total: %d", totalPeriod1))
	println()

	println("[SCENARIO] 4. Change ratio to 0/50/0/50")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 0,
		emission.DEVOPS, 5000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 5000,
	)
	println("[INFO] distribution ratio changed to 0/50/0/50")
	println()

	println("[SCENARIO] 5. Skip 1 block and mint (Period 2)")
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

	emission.MintAndDistributeGns(cross)
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	totalPool := emission.GetDistributedToCommunityPool()
	totalXGns := emission.GetDistributedToGovStaker()

	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	period2Pool := totalPool - period1Pool
	period2XGns := totalXGns - period1XGns
	totalPeriod2 := period2Staker + period2Devops + period2Pool + period2XGns

	println(ufmt.Sprintf("[INFO] Period 2 distributed: Staker=%d, DevOps=%d, Pool=%d, xGNS=%d",
		period2Staker, period2Devops, period2Pool, period2XGns))
	println("[INFO] expected Staker: 0 (0%)")
	println("[INFO] expected DevOps: 17836758 (50%)")
	println("[INFO] expected Pool: 0 (0%)")
	println("[INFO] expected xGNS: 17836758 (50%)")
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker: %d", period2Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 2 DevOps: %d", period2Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 2 Pool: %d", period2Pool))
	println(ufmt.Sprintf("[EXPECTED] Period 2 xGNS: %d", period2XGns))
	println(ufmt.Sprintf("[EXPECTED] Period 2 total: %d", totalPeriod2))
	println()

	println("[SCENARIO] 6. Change ratio to 30/30/30/10")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 3000,
		emission.DEVOPS, 3000,
		emission.COMMUNITY_POOL, 3000,
		emission.GOV_STAKER, 1000,
	)
	println("[INFO] distribution ratio changed to 30/30/30/10")
	println()

	println("[SCENARIO] 7. Skip 1 block and mint (Period 3)")
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
	finalPool := emission.GetDistributedToCommunityPool()
	finalXGns := emission.GetDistributedToGovStaker()

	period3Staker := finalStaker - totalStaker
	period3Devops := finalDevops - totalDevops
	period3Pool := finalPool - totalPool
	period3XGns := finalXGns - totalXGns
	totalPeriod3 := period3Staker + period3Devops + period3Pool + period3XGns

	println(ufmt.Sprintf("[INFO] Period 3 distributed: Staker=%d, DevOps=%d, Pool=%d, xGNS=%d",
		period3Staker, period3Devops, period3Pool, period3XGns))
	println("[INFO] expected Staker: 10702054 (30%)")
	println("[INFO] expected DevOps: 10702054 (30%)")
	println("[INFO] expected Pool: 10702054 (30%)")
	println("[INFO] expected xGNS: 3567351 (10%)")
	println(ufmt.Sprintf("[EXPECTED] Period 3 Staker: %d", period3Staker))
	println(ufmt.Sprintf("[EXPECTED] Period 3 DevOps: %d", period3Devops))
	println(ufmt.Sprintf("[EXPECTED] Period 3 Pool: %d", period3Pool))
	println(ufmt.Sprintf("[EXPECTED] Period 3 xGNS: %d", period3XGns))
	println(ufmt.Sprintf("[EXPECTED] Period 3 total: %d", totalPeriod3))

	println()
	totalDistributed := finalStaker + finalDevops + finalPool + finalXGns
	println("[INFO] expected total distributed: 107020542")
	println(ufmt.Sprintf("[EXPECTED] Total distributed: %d", totalDistributed))
}

// Output:
// [SCENARIO] 1. Setup initial 70/25/5/0 distribution ratio
// [INFO] distribution ratio set to 70/25/5/0 (Staker/DevOps/Pool/xGNS)
//
// [SCENARIO] 2. Set distribution start time
// [INFO] initial distribution: all recipients = 0
//
// [SCENARIO] 3. Skip 1 block and mint (Period 1)
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [INFO] Period 1 distributed: Staker=24971460, DevOps=8918378, Pool=1783675, xGNS=0
// [INFO] expected Staker: 24971460 (70%)
// [INFO] expected DevOps: 8918378 (25%)
// [INFO] expected Community: 1783675 (5%)
// [INFO] expected xGNS: 0 (0%)
// [EXPECTED] Period 1 Staker: 24971460
// [EXPECTED] Period 1 DevOps: 8918378
// [EXPECTED] Period 1 Pool: 1783675
// [EXPECTED] Period 1 xGNS: 0
// [EXPECTED] Period 1 total: 35673513
//
// [SCENARIO] 4. Change ratio to 0/50/0/50
// [INFO] distribution ratio changed to 0/50/0/50
//
// [SCENARIO] 5. Skip 1 block and mint (Period 2)
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [INFO] Period 2 distributed: Staker=0, DevOps=17836758, Pool=0, xGNS=17836758
// [INFO] expected Staker: 0 (0%)
// [INFO] expected DevOps: 17836758 (50%)
// [INFO] expected Pool: 0 (0%)
// [INFO] expected xGNS: 17836758 (50%)
// [EXPECTED] Period 2 Staker: 0
// [EXPECTED] Period 2 DevOps: 17836758
// [EXPECTED] Period 2 Pool: 0
// [EXPECTED] Period 2 xGNS: 17836758
// [EXPECTED] Period 2 total: 35673516
//
// [SCENARIO] 6. Change ratio to 30/30/30/10
// [INFO] distribution ratio changed to 30/30/30/10
//
// [SCENARIO] 7. Skip 1 block and mint (Period 3)
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 5 (1 block)
// [INFO] calculated total emission: 7134703 * 5 = 35673515
//
// [INFO] Period 3 distributed: Staker=10702054, DevOps=10702054, Pool=10702054, xGNS=3567351
// [INFO] expected Staker: 10702054 (30%)
// [INFO] expected DevOps: 10702054 (30%)
// [INFO] expected Pool: 10702054 (30%)
// [INFO] expected xGNS: 3567351 (10%)
// [EXPECTED] Period 3 Staker: 10702054
// [EXPECTED] Period 3 DevOps: 10702054
// [EXPECTED] Period 3 Pool: 10702054
// [EXPECTED] Period 3 xGNS: 3567351
// [EXPECTED] Period 3 total: 35673513
//
// [INFO] expected total distributed: 107020542
// [EXPECTED] Total distributed: 107020542
