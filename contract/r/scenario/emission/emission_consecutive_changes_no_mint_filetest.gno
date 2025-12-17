// Emission consecutive ratio changes without minting scenario test
// Scenario: Change distribution ratio multiple times without intermediate minting
//
// Setup:
// - Initial ratio: 50/50
// - Change to 70/30 (no minting)
// - Change to 80/20 (no minting)
// - Then accumulate and mint
//
// Expected Behavior:
// - Since no emissions accumulated under intermediate ratios, only final ratio (80/20) should be used
// - All emissions distributed at final ratio

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
	testConsecutiveChangesWithoutMinting()
}

func testConsecutiveChangesWithoutMinting() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[SCENARIO] 2. Set initial ratio to 50/50")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000, // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Initial ratio: 50/50")

	println()
	println("[SCENARIO] 3. Immediately change to 70/30 (no emissions accumulated)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000, // 70%
		emission.DEVOPS, 3000, // 30%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Changed to 70/30 without minting")

	println()
	println("[SCENARIO] 4. Immediately change to 80/20 (still no emissions accumulated)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000, // 80%
		emission.DEVOPS, 2000, // 20%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Changed to 80/20 without minting")

	println()
	println("[SCENARIO] 5. Verify no distributions yet")
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()

	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] Confirmed: No distributions yet (Staker=0, DevOps=0)")

	println()
	println("[SCENARIO] 6. Skip 30 days to accumulate emissions")
	testing.SkipHeights(2592000) // 30 days
	println("[INFO] Accumulated emissions for 30 days")

	println()
	println("[SCENARIO] 7. Mint accumulated emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[SCENARIO] 8. Verify all emissions use FINAL ratio (80/20)")
	stakerAfter := emission.GetDistributedToStaker()
	devopsAfter := emission.GetDistributedToDevOps()
	communityAfter := emission.GetDistributedToCommunityPool()
	govAfter := emission.GetDistributedToGovStaker()

	println(ufmt.Sprintf("[INFO] Distributed: Staker=%d, DevOps=%d, Community=%d, Gov=%d",
		stakerAfter, devopsAfter, communityAfter, govAfter))

	// Verify all recipients have values
	uassert.True(t, stakerAfter > 0)
	uassert.True(t, devopsAfter > 0)
	uassert.Equal(t, int64(0), communityAfter)
	uassert.Equal(t, int64(0), govAfter)

	// Calculate total distributed
	totalDistributed := stakerAfter + devopsAfter + communityAfter + govAfter
	println(ufmt.Sprintf("[INFO] Total distributed: %d", totalDistributed))

	// Verify exact amounts using pre-calculated expected values
	// Expected values from output: Staker=73972035635522, DevOps=18493008908880
	expectedStaker := int64(73972035635522)
	expectedDevops := int64(18493008908880)
	expectedTotal := expectedStaker + expectedDevops

	println(ufmt.Sprintf("[EXPECTED] Staker should be %d, got %d", expectedStaker, stakerAfter))
	println(ufmt.Sprintf("[EXPECTED] DevOps should be %d, got %d", expectedDevops, devopsAfter))
	println(ufmt.Sprintf("[EXPECTED] Total should be %d, got %d", expectedTotal, totalDistributed))

	uassert.Equal(t, expectedStaker, stakerAfter)
	uassert.Equal(t, expectedDevops, devopsAfter)
	uassert.Equal(t, expectedTotal, totalDistributed)

	// Verify distribution ratio as additional check
	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 4.0 // 80/20

	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~%.2f (80/20), got %.2f", expectedRatio, ratio))
	uassert.True(t, ratio > expectedRatio*0.99 && ratio < expectedRatio*1.01)

	// Verify sum equals total
	sum := stakerAfter + devopsAfter
	println(ufmt.Sprintf("[EXPECTED] Sum of distributions should equal total: %d == %d", sum, totalDistributed))
	uassert.Equal(t, totalDistributed, sum)
	println()
}

// Output:
// [SCENARIO] 1. Set distribution start time
// [INFO] Distribution start time set
//
// [SCENARIO] 2. Set initial ratio to 50/50
// [INFO] Initial ratio: 50/50
//
// [SCENARIO] 3. Immediately change to 70/30 (no emissions accumulated)
// [INFO] Changed to 70/30 without minting
//
// [SCENARIO] 4. Immediately change to 80/20 (still no emissions accumulated)
// [INFO] Changed to 80/20 without minting
//
// [SCENARIO] 5. Verify no distributions yet
// [INFO] Confirmed: No distributions yet (Staker=0, DevOps=0)
//
// [SCENARIO] 6. Skip 30 days to accumulate emissions
// [INFO] Accumulated emissions for 30 days
//
// [SCENARIO] 7. Mint accumulated emissions
// [INFO] MintAndDistributeGns called
//
// [SCENARIO] 8. Verify all emissions use FINAL ratio (80/20)
// [INFO] Distributed: Staker=73972035635522, DevOps=18493008908880, Community=0, Gov=0
// [INFO] Total distributed: 92465044544402
// [EXPECTED] Staker should be 73972035635522, got 73972035635522
// [EXPECTED] DevOps should be 18493008908880, got 18493008908880
// [EXPECTED] Total should be 92465044544402, got 92465044544402
// [EXPECTED] Ratio should be ~4.00 (80/20), got 4.00
// [EXPECTED] Sum of distributions should equal total: 92465044544402 == 92465044544402
//
