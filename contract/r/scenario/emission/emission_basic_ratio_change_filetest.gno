// Emission basic ratio change scenario test
// Scenario: Basic non-retroactive distribution when ratio changes
//
// Setup:
// - Period 1: Set 50/50 ratio and accumulate for 50 days
// - Change ratio to 80/20 (automatically distributes Period 1 at 50/50)
// - Period 2: Accumulate for 5 more days
//
// Expected Behavior:
// - Period 1 emissions (50 days) distributed at OLD ratio (50/50)
// - Period 2 emissions (5 days) distributed at NEW ratio (80/20)
//
// This is the fundamental test verifying that ratio changes do NOT
// retroactively affect previously accumulated emissions.

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
	testNoRetroactiveApplication()
}

func testNoRetroactiveApplication() {
	println("[SCENARIO] 1. Setup initial 50/50 distribution ratio")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000,
		emission.DEVOPS, 5000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] distribution ratio set to 50/50 (Staker/DevOps)")
	println()

	println("[SCENARIO] 2. Set distribution start time")
	now := time.Now().Unix()
	distributionStartTime := now + 1
	emission.SetDistributionStartTime(cross, distributionStartTime)
	println("[INFO] initial distribution: Staker=0, DevOps=0")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 50 days (864,000 heights)")
	testing.SkipHeights(864000)
	timestampAfterPeriod1 := time.Now().Unix()
	println("[INFO] emissions accumulated without distribution")
	println()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (50 days)", elapsedSeconds1))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond1, elapsedSeconds1, expectedTotalEmission1))
	println()

	println("[SCENARIO] 4. Change distribution ratio to 80/20")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000,
		emission.DEVOPS, 2000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)

	println("[INFO] distributed: Staker=15410958480000, DevOps=15410958480000, Community=0, Gov=0")

	stakerAfterRatioChange := emission.GetDistributedToStaker()
	devopsAfterRatioChange := emission.GetDistributedToDevOps()
	communityAfterRatioChange := emission.GetDistributedToCommunityPool()
	govAfterRatioChange := emission.GetDistributedToGovStaker()
	totalPeriod1 := stakerAfterRatioChange + devopsAfterRatioChange + communityAfterRatioChange + govAfterRatioChange

	println("[INFO] expected Staker: 15410958480000 (50%)")
	println("[INFO] expected DevOps: 15410958480000 (50%)")
	println(ufmt.Sprintf("[EXPECTED] Period 1 Staker: %d", stakerAfterRatioChange))
	println(ufmt.Sprintf("[EXPECTED] Period 1 DevOps: %d", devopsAfterRatioChange))
	println(ufmt.Sprintf("[EXPECTED] Period 1 total: %d", totalPeriod1))
	println()

	println("[SCENARIO] 5. Accumulate 5 more days and distribute")
	testing.SkipHeights(86400)
	timestampAfterPeriod2 := time.Now().Unix()

	// Calculate emission details for Period 2
	emissionPerSecond2 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod2)
	elapsedSeconds2 := timestampAfterPeriod2 - timestampAfterPeriod1
	expectedTotalEmission2 := emissionPerSecond2 * elapsedSeconds2

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond2))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (5 days)", elapsedSeconds2))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond2, elapsedSeconds2, expectedTotalEmission2))
	println()

	emission.MintAndDistributeGns(cross)
	stakerAfterNew := emission.GetDistributedToStaker()
	devopsAfterNew := emission.GetDistributedToDevOps()
	communityAfterNew := emission.GetDistributedToCommunityPool()
	govAfterNew := emission.GetDistributedToGovStaker()

	println("[INFO] new emissions: Staker=2465753356800, DevOps=616438339200, Community=0, Gov=0")

	stakerIncrement := stakerAfterNew - stakerAfterRatioChange
	devopsIncrement := devopsAfterNew - devopsAfterRatioChange
	totalPeriod2 := stakerIncrement + devopsIncrement

	println("[INFO] expected Staker increment: 2465753356800 (80%)")
	println("[INFO] expected DevOps increment: 616438339200 (20%)")
	println(ufmt.Sprintf("[EXPECTED] Period 2 Staker: %d", stakerIncrement))
	println(ufmt.Sprintf("[EXPECTED] Period 2 DevOps: %d", devopsIncrement))
	println(ufmt.Sprintf("[EXPECTED] Period 2 total: %d", totalPeriod2))

	println()
	totalDistributed := stakerAfterNew + devopsAfterNew + communityAfterNew + govAfterNew
	println("[INFO] expected total distributed: 33904108656000")
	println(ufmt.Sprintf("[EXPECTED] Total distributed: %d", totalDistributed))
}

// Output:
// [SCENARIO] 1. Setup initial 50/50 distribution ratio
// [INFO] distribution ratio set to 50/50 (Staker/DevOps)
//
// [SCENARIO] 2. Set distribution start time
// [INFO] initial distribution: Staker=0, DevOps=0
//
// [SCENARIO] 3. Accumulate emissions for 50 days (864,000 heights)
// [INFO] emissions accumulated without distribution
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (50 days)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 4. Change distribution ratio to 80/20
// [INFO] distributed: Staker=15410958480000, DevOps=15410958480000, Community=0, Gov=0
// [INFO] expected Staker: 15410958480000 (50%)
// [INFO] expected DevOps: 15410958480000 (50%)
// [EXPECTED] Period 1 Staker: 15410958480000
// [EXPECTED] Period 1 DevOps: 15410958480000
// [EXPECTED] Period 1 total: 30821916960000
//
// [SCENARIO] 5. Accumulate 5 more days and distribute
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 432000 (5 days)
// [INFO] calculated total emission: 7134703 * 432000 = 3082191696000
//
// [INFO] new emissions: Staker=2465753356800, DevOps=616438339200, Community=0, Gov=0
// [INFO] expected Staker increment: 2465753356800 (80%)
// [INFO] expected DevOps increment: 616438339200 (20%)
// [EXPECTED] Period 2 Staker: 2465753356800
// [EXPECTED] Period 2 DevOps: 616438339200
// [EXPECTED] Period 2 total: 3082191696000
//
// [INFO] expected total distributed: 33904108656000
// [EXPECTED] Total distributed: 33904108656000
