// Emission ratio change without accumulation scenario test
// Scenario: Change distribution ratio when no emissions have accumulated
//
// Setup:
// - Immediately change ratio without accumulating emissions
// - Then let emissions accumulate and mint
//
// Expected Behavior:
// - Ratio change should work without errors when no emissions exist
// - All subsequent emissions use the new ratio

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
	testRatioChangeWithoutAccumulation()
}

func testRatioChangeWithoutAccumulation() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println()

	println("[SCENARIO] 2. Change ratio to 80/20 without accumulation")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000,
		emission.DEVOPS, 2000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)

	// Get all recipients before accumulation
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()
	communityBefore := emission.GetDistributedToCommunityPool()
	govBefore := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Before accumulation: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		stakerBefore, devopsBefore, communityBefore, govBefore))

	// All should be zero before accumulation
	println("[EXPECTED] All recipients should be 0 before accumulation")
	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	uassert.Equal(t, int64(0), communityBefore)
	uassert.Equal(t, int64(0), govBefore)

	println("[INFO] ratio set to 80/20 without accumulated emissions")
	println("[EXPECTED] no errors when changing ratio without accumulation")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 60 days")
	testing.SkipHeights(5184000)
	println("[INFO] 60 days elapsed")
	println()

	println("[SCENARIO] 4. Distribute accumulated emissions")
	emission.MintAndDistributeGns(cross)

	// Get all recipients after distribution
	stakerAfter := emission.GetDistributedToStaker()
	devopsAfter := emission.GetDistributedToDevOps()
	communityAfter := emission.GetDistributedToCommunityPool()
	govAfter := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		stakerAfter, devopsAfter, communityAfter, govAfter))

	// Calculate total
	totalDistributed := stakerAfter + devopsAfter + communityAfter + govAfter
	println(ufmt.Sprintf("[INFO] Total distributed: %d", totalDistributed))

	// Pre-calculated expected values (from Output section)
	expectedStaker := int64(147944636339522)
	expectedDevops := int64(36986159084880)
	expectedCommunity := int64(0)
	expectedGov := int64(0)
	expectedTotal := expectedStaker + expectedDevops + expectedCommunity + expectedGov

	// Exact assertions
	println(ufmt.Sprintf("[EXPECTED] Staker should be %d, got %d", expectedStaker, stakerAfter))
	uassert.Equal(t, expectedStaker, stakerAfter)

	println(ufmt.Sprintf("[EXPECTED] DevOps should be %d, got %d", expectedDevops, devopsAfter))
	uassert.Equal(t, expectedDevops, devopsAfter)

	println(ufmt.Sprintf("[EXPECTED] Community should be %d, got %d", expectedCommunity, communityAfter))
	uassert.Equal(t, expectedCommunity, communityAfter)

	println(ufmt.Sprintf("[EXPECTED] Gov should be %d, got %d", expectedGov, govAfter))
	uassert.Equal(t, expectedGov, govAfter)

	// Ratio verification (tighter tolerance)
	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 8000.0 / 2000.0
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~%.2f (80/20), got %.2f", expectedRatio, ratio))
	uassert.True(t, ratio > expectedRatio*0.99 && ratio < expectedRatio*1.01)

	// Sum verification
	println(ufmt.Sprintf("[EXPECTED] Sum should equal total: %d == %d", totalDistributed, expectedTotal))
	uassert.Equal(t, expectedTotal, totalDistributed)
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Change ratio to 80/20 without accumulation
// [INFO] Before accumulation: Staker=0, DevOps=0, Community=0, Gov=0
// [EXPECTED] All recipients should be 0 before accumulation
// [INFO] ratio set to 80/20 without accumulated emissions
// [EXPECTED] no errors when changing ratio without accumulation
//
// [SCENARIO] 3. Accumulate emissions for 60 days
// [INFO] 60 days elapsed
//
// [SCENARIO] 4. Distribute accumulated emissions
// [INFO] Distributed: Staker=147944636339522, DevOps=36986159084880, Community=0, Gov=0
// [INFO] Total distributed: 184930795424402
// [EXPECTED] Staker should be 147944636339522, got 147944636339522
// [EXPECTED] DevOps should be 36986159084880, got 36986159084880
// [EXPECTED] Community should be 0, got 0
// [EXPECTED] Gov should be 0, got 0
// [EXPECTED] Ratio should be ~4.00 (80/20), got 4.00
// [EXPECTED] Sum should equal total: 184930795424402 == 184930795424402
