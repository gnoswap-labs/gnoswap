// Emission basic ratio change scenario test
// Scenario: Basic non-retroactive distribution when ratio changes
//
// Setup:
// - Period 1: Set 50/50 ratio and accumulate for 10 days
// - Change ratio to 80/20 (automatically distributes Period 1 at 50/50)
// - Period 2: Accumulate for 1 more day
//
// Expected Behavior:
// - Period 1 emissions (10 days) distributed at OLD ratio (50/50)
// - Period 2 emissions (1 day) distributed at NEW ratio (80/20)
//
// This is the fundamental test verifying that ratio changes do NOT
// retroactively affect previously accumulated emissions.

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
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()
	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] initial distribution: Staker=0, DevOps=0")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 10 days (864,000 heights)")
	testing.SkipHeights(864000)
	timestampAfterPeriod1 := time.Now().Unix()
	println("[INFO] emissions accumulated without distribution")
	println()

	// Calculate emission details for Period 1
	emissionPerSecond1 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod1)
	elapsedSeconds1 := timestampAfterPeriod1 - distributionStartTime + 1
	expectedTotalEmission1 := emissionPerSecond1 * elapsedSeconds1

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond1))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (from distribution start time, inclusive range)", elapsedSeconds1))
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
	stakerAfterRatioChange := emission.GetDistributedToStaker()
	devopsAfterRatioChange := emission.GetDistributedToDevOps()
	communityAfterRatioChange := emission.GetDistributedToCommunityPool()
	govAfterRatioChange := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		stakerAfterRatioChange, devopsAfterRatioChange, communityAfterRatioChange, govAfterRatioChange))

	expectedStaker1 := int64(15410958480000)
	expectedDevops1 := int64(15410958480000)
	totalPeriod1 := stakerAfterRatioChange + devopsAfterRatioChange + communityAfterRatioChange + govAfterRatioChange

	println(ufmt.Sprintf("[EXPECTED] Period 1 (10 days at 50/50) - Staker should be %d, got %d", expectedStaker1, stakerAfterRatioChange))
	println(ufmt.Sprintf("[EXPECTED] Period 1 (10 days at 50/50) - DevOps should be %d, got %d", expectedDevops1, devopsAfterRatioChange))
	println(ufmt.Sprintf("[EXPECTED] Period 1 total: %d", totalPeriod1))

	uassert.Equal(t, expectedStaker1, stakerAfterRatioChange)
	uassert.Equal(t, expectedDevops1, devopsAfterRatioChange)
	uassert.Equal(t, int64(0), communityAfterRatioChange)
	uassert.Equal(t, int64(0), govAfterRatioChange)

	// Verify ratio
	ratio := float64(stakerAfterRatioChange) / float64(devopsAfterRatioChange)
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~1.00 (50/50), got %.2f", ratio))
	uassert.True(t, ratio > 0.99 && ratio < 1.01)
	println()

	println("[SCENARIO] 5. Accumulate 1 more day and distribute")
	testing.SkipHeights(86400)
	timestampAfterPeriod2 := time.Now().Unix()

	// Calculate emission details for Period 2
	emissionPerSecond2 := gns.GetEmissionAmountPerSecondByTimestamp(timestampAfterPeriod2)
	elapsedSeconds2 := timestampAfterPeriod2 - timestampAfterPeriod1
	expectedTotalEmission2 := emissionPerSecond2 * elapsedSeconds2

	println(ufmt.Sprintf("[INFO] emission per second: %d", emissionPerSecond2))
	println(ufmt.Sprintf("[INFO] elapsed seconds: %d (1 day, subsequent minting)", elapsedSeconds2))
	println(ufmt.Sprintf("[INFO] calculated total emission: %d * %d = %d", emissionPerSecond2, elapsedSeconds2, expectedTotalEmission2))
	println()

	emission.MintAndDistributeGns(cross)
	stakerAfterNew := emission.GetDistributedToStaker()
	devopsAfterNew := emission.GetDistributedToDevOps()
	communityAfterNew := emission.GetDistributedToCommunityPool()
	govAfterNew := emission.GetDistributedToGovStaker()

	stakerIncrement := stakerAfterNew - stakerAfterRatioChange
	devopsIncrement := devopsAfterNew - devopsAfterRatioChange

	println(ufmt.Sprintf("[INFO] new emissions: Staker=%d, DevOps=%d", stakerIncrement, devopsIncrement))

	expectedStakerIncrement := int64(2465753356800)
	expectedDevopsIncrement := int64(616438339200)
	totalPeriod2 := stakerIncrement + devopsIncrement

	println(ufmt.Sprintf("[EXPECTED] Period 2 (1 day at 80/20) - Staker increment should be %d, got %d", expectedStakerIncrement, stakerIncrement))
	println(ufmt.Sprintf("[EXPECTED] Period 2 (1 day at 80/20) - DevOps increment should be %d, got %d", expectedDevopsIncrement, devopsIncrement))
	println(ufmt.Sprintf("[EXPECTED] Period 2 total: %d", totalPeriod2))

	uassert.Equal(t, expectedStakerIncrement, stakerIncrement)
	uassert.Equal(t, expectedDevopsIncrement, devopsIncrement)

	// Verify new ratio
	newRatio := float64(stakerIncrement) / float64(devopsIncrement)
	println(ufmt.Sprintf("[EXPECTED] New ratio should be ~4.00 (80/20), got %.2f", newRatio))
	uassert.True(t, newRatio > 3.99 && newRatio < 4.01)

	// Verify overall totals
	totalDistributed := stakerAfterNew + devopsAfterNew + communityAfterNew + govAfterNew
	expectedTotalDistributed := int64(33904108656000)

	println(ufmt.Sprintf("[EXPECTED] Total distributed should be %d, got %d", expectedTotalDistributed, totalDistributed))
	uassert.Equal(t, expectedTotalDistributed, totalDistributed)
}

// Output:
// [SCENARIO] 1. Setup initial 50/50 distribution ratio
// [INFO] distribution ratio set to 50/50 (Staker/DevOps)
//
// [SCENARIO] 2. Set distribution start time
// [INFO] initial distribution: Staker=0, DevOps=0
//
// [SCENARIO] 3. Accumulate emissions for 10 days (864,000 heights)
// [INFO] emissions accumulated without distribution
//
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 4320000 (from distribution start time, inclusive range)
// [INFO] calculated total emission: 7134703 * 4320000 = 30821916960000
//
// [SCENARIO] 4. Change distribution ratio to 80/20
// [INFO] distributed: Staker=15410958480000, DevOps=15410958480000, Community=0, Gov=0
// [EXPECTED] Period 1 (10 days at 50/50) - Staker should be 15410958480000, got 15410958480000
// [EXPECTED] Period 1 (10 days at 50/50) - DevOps should be 15410958480000, got 15410958480000
// [EXPECTED] Period 1 total: 30821916960000
// [EXPECTED] Ratio should be ~1.00 (50/50), got 1.00
//
// [SCENARIO] 5. Accumulate 1 more day and distribute
// [INFO] emission per second: 7134703
// [INFO] elapsed seconds: 432000 (1 day, subsequent minting)
// [INFO] calculated total emission: 7134703 * 432000 = 3082191696000
//
// [INFO] new emissions: Staker=2465753356800, DevOps=616438339200
// [EXPECTED] Period 2 (1 day at 80/20) - Staker increment should be 2465753356800, got 2465753356800
// [EXPECTED] Period 2 (1 day at 80/20) - DevOps increment should be 616438339200, got 616438339200
// [EXPECTED] Period 2 total: 3082191696000
// [EXPECTED] New ratio should be ~4.00 (80/20), got 4.00
// [EXPECTED] Total distributed should be 33904108656000, got 33904108656000
