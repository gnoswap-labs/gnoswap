// Emission retroactive distribution scenario test
// Scenario: Change distribution ratio after emissions have accumulated
//
// Setup:
// - Days 1-10: Ratios are 50% Liquidity Staker, 50% DevOps
// - No minting occurs during this period -> emissions accumulate
// - Day 11: Ratios change to 80% Liquidity Staker, 20% DevOps
//
// Expected Behavior:
// - The accumulated 10-day emissions should be distributed with OLD ratios (50/50)
// - Only new emissions after Day 11 use new ratios (80/20)
//
// This test verifies that changing distribution percentages does NOT retroactively
// affect accumulated emissions from previous periods.

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
	emission.SetDistributionStartTime(cross, now+100)
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()
	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] initial distribution: Staker=0, DevOps=0")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 10 days (864,000 heights)")
	testing.SkipHeights(864000)
	println("[INFO] emissions accumulated without distribution")
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

	// Verify exact amounts for 10 days at 50/50
	expectedStaker1 := int64(15410605312201)
	expectedDevops1 := int64(15410605312201)
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
	emission.MintAndDistributeGns(cross)
	stakerAfterNew := emission.GetDistributedToStaker()
	devopsAfterNew := emission.GetDistributedToDevOps()
	communityAfterNew := emission.GetDistributedToCommunityPool()
	govAfterNew := emission.GetDistributedToGovStaker()

	stakerIncrement := stakerAfterNew - stakerAfterRatioChange
	devopsIncrement := devopsAfterNew - devopsAfterRatioChange

	println(ufmt.Sprintf("[INFO] new emissions: Staker=%d, DevOps=%d", stakerIncrement, devopsIncrement))

	// Verify exact amounts for 1 day at 80/20
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
	expectedTotalDistributed := expectedStaker1 + expectedDevops1 + expectedStakerIncrement + expectedDevopsIncrement

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
// [SCENARIO] 4. Change distribution ratio to 80/20
// [INFO] distributed: Staker=15410605312201, DevOps=15410605312201, Community=0, Gov=0
// [EXPECTED] Period 1 (10 days at 50/50) - Staker should be 15410605312201, got 15410605312201
// [EXPECTED] Period 1 (10 days at 50/50) - DevOps should be 15410605312201, got 15410605312201
// [EXPECTED] Period 1 total: 30821210624402
// [EXPECTED] Ratio should be ~1.00 (50/50), got 1.00
//
// [SCENARIO] 5. Accumulate 1 more day and distribute
// [INFO] new emissions: Staker=2465753356800, DevOps=616438339200
// [EXPECTED] Period 2 (1 day at 80/20) - Staker increment should be 2465753356800, got 2465753356800
// [EXPECTED] Period 2 (1 day at 80/20) - DevOps increment should be 616438339200, got 616438339200
// [EXPECTED] Period 2 total: 3082191696000
// [EXPECTED] New ratio should be ~4.00 (80/20), got 4.00
// [EXPECTED] Total distributed should be 33903402320402, got 33903402320402
