package emission

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

var testAdmin = testutils.TestAddress("admin")

// TestChangeDistributionPct_NoRetroactiveApplication verifies that changing distribution
// percentages does not retroactively affect accumulated emissions from previous periods.
//
// Scenario:
// - Days 1-10: Ratios are 50% Liquidity Staker, 50% DevOps
// - No minting occurs during this period -> 10,000 tokens accumulate
// - Day 11: Ratios change to 80% Liquidity Staker, 20% DevOps
// - Expected: The 10,000 accumulated tokens should be distributed with OLD ratios (50/50)
// - Expected: Only new emissions after Day 11 use new ratios (80/20)
func TestChangeDistributionPct_NoRetroactiveApplication(t *testing.T) {
	resetObject(t)

	// Setup initial ratios: 50% staker, 50% devops
	testing.SetRealm(adminRealm)
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 5000, // 50%
		DEVOPS, 5000,           // 50%
		COMMUNITY_POOL, 0,      // 0%
		GOV_STAKER, 0,          // 0%
	)

	// Set distribution start time
	now := time.Now().Unix()
	SetDistributionStartTime(cross, now+100)

	// Skip 10 days without minting (simulating no user activity)
	// 10 days = 10 * 24 * 60 * 60 seconds = 864,000 seconds
	testing.SkipHeights(864000)

	// Record balances before ratio change
	stakerBefore := GetDistributedToStaker()
	devopsBefore := GetDistributedToDevOps()

	uassert.Equal(t, int64(0), stakerBefore, "Staker should have 0 before first distribution")
	uassert.Equal(t, int64(0), devopsBefore, "DevOps should have 0 before first distribution")

	// Change ratios to 80/20
	testing.SetRealm(adminRealm)
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 8000, // 80%
		DEVOPS, 2000,           // 20%
		COMMUNITY_POOL, 0,      // 0%
		GOV_STAKER, 0,          // 0%
	)

	// Verify: The accumulated 10-day emissions should have been distributed
	// at the OLD 50/50 ratio when ChangeDistributionPct was called
	stakerAfterRatioChange := GetDistributedToStaker()
	devopsAfterRatioChange := GetDistributedToDevOps()

	// Both should have received equal amounts (50/50 split of accumulated emissions)
	expectedRatio := float64(stakerAfterRatioChange) / float64(devopsAfterRatioChange)

	uassert.True(t, stakerAfterRatioChange > 0, "Staker should have received tokens")
	uassert.True(t, devopsAfterRatioChange > 0, "DevOps should have received tokens")

	// Ratio should be approximately 1.0 (50/50), not 4.0 (80/20)
	// Allow small deviation due to integer division
	uassert.True(t, expectedRatio > 0.9 && expectedRatio < 1.1,
		ufmt.Sprintf("Distribution ratio should be ~1.0 (50/50), got %.2f", expectedRatio))

	// Skip one more day and trigger new emission
	testing.SkipHeights(86400) // 1 day

	MintAndDistributeGns(cross)

	stakerAfterNewEmission := GetDistributedToStaker()
	devopsAfterNewEmission := GetDistributedToDevOps()

	// Calculate incremental distribution (new emission)
	stakerIncrement := stakerAfterNewEmission - stakerAfterRatioChange
	devopsIncrement := devopsAfterNewEmission - devopsAfterRatioChange

	if stakerIncrement > 0 && devopsIncrement > 0 {
		newEmissionRatio := float64(stakerIncrement) / float64(devopsIncrement)

		// New emissions should use 80/20 ratio (4.0)
		uassert.True(t, newEmissionRatio > 3.5 && newEmissionRatio < 4.5,
			ufmt.Sprintf("New emission ratio should be ~4.0 (80/20), got %.2f", newEmissionRatio))
	}
}

// TestChangeDistributionPct_MultipleChanges tests multiple ratio changes to ensure
// each period's emissions are distributed with their corresponding ratios.
func TestChangeDistributionPct_MultipleChanges(t *testing.T) {
	resetObject(t)

	testing.SetRealm(adminRealm)

	now := time.Now().Unix()
	SetDistributionStartTime(cross, now+100)

	// Period 1: 70/30 ratio
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 7000, // 70%
		DEVOPS, 3000,           // 30%
		COMMUNITY_POOL, 0,
		GOV_STAKER, 0,
	)

	testing.SkipHeights(1728000) // 20 days

	// Period 2: Change to 60/40 (should distribute period 1 emissions at 70/30)
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 6000, // 60%
		DEVOPS, 4000,           // 40%
		COMMUNITY_POOL, 0,
		GOV_STAKER, 0,
	)

	period1Staker := GetDistributedToStaker()
	period1Devops := GetDistributedToDevOps()

	uassert.True(t, period1Staker > 0)
	uassert.True(t, period1Devops > 0)

	ratio1 := float64(period1Staker) / float64(period1Devops)
	expectedRatio1 := 7000.0 / 3000.0 // 2.333...

	uassert.True(t, ratio1 > expectedRatio1*0.9 && ratio1 < expectedRatio1*1.1,
		ufmt.Sprintf("Period 1 ratio should be ~2.33 (70/30), got %.2f", ratio1))

	testing.SkipHeights(1728000) // 20 days

	// Period 3: Change to 50/50 (should distribute period 2 emissions at 60/40)
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 5000, // 50%
		DEVOPS, 5000,           // 50%
		COMMUNITY_POOL, 0,
		GOV_STAKER, 0,
	)

	period2Staker := GetDistributedToStaker() - period1Staker
	period2Devops := GetDistributedToDevOps() - period1Devops

	if period2Staker > 0 && period2Devops > 0 {
		ratio2 := float64(period2Staker) / float64(period2Devops)
		expectedRatio2 := 6000.0 / 4000.0 // 1.5

		uassert.True(t, ratio2 > expectedRatio2*0.9 && ratio2 < expectedRatio2*1.1,
			ufmt.Sprintf("Period 2 ratio should be ~1.5 (60/40), got %.2f", ratio2))
	}
}

// TestChangeDistributionPct_WithoutAccumulatedEmissions verifies that changing ratios
// when there are no accumulated emissions works correctly.
func TestChangeDistributionPct_WithoutAccumulatedEmissions(t *testing.T) {
	resetObject(t)

	testing.SetRealm(adminRealm)

	now := time.Now().Unix()
	SetDistributionStartTime(cross, now+100)

	// Immediately change ratio without accumulating emissions
	ChangeDistributionPct(
		cross,
		LIQUIDITY_STAKER, 8000,
		DEVOPS, 2000,
		COMMUNITY_POOL, 0,
		GOV_STAKER, 0,
	)

	// Should not panic or cause errors
	stakerBefore := GetDistributedToStaker()
	devopsBefore := GetDistributedToDevOps()

	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)

	// Skip time and mint
	testing.SkipHeights(5184000) // 60 days
	MintAndDistributeGns(cross)

	stakerAfter := GetDistributedToStaker()
	devopsAfter := GetDistributedToDevOps()

	uassert.True(t, stakerAfter > 0)
	uassert.True(t, devopsAfter > 0)

	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 8000.0 / 2000.0 // 4.0

	uassert.True(t, ratio > expectedRatio*0.9 && ratio < expectedRatio*1.1,
		ufmt.Sprintf("Ratio should be ~4.0 (80/20), got %.2f", ratio))
}
