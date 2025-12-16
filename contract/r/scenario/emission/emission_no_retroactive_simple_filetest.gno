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
	println("[SCENARIO] Emission Distribution Ratio Change - No Retroactive Application")
	println("==============================================================================")
	println()

	testNoRetroactiveApplication()
}

func testNoRetroactiveApplication() {
	println("[STEP 1] Setup initial 50/50 distribution ratio")
	testing.SetRealm(adminRealm)

	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,      // 0%
		emission.GOV_STAKER, 0,          // 0%
	)
	println("[INFO] Distribution ratio set to 50/50 (Staker/DevOps)")

	println()
	println("[STEP 2] Set distribution start time and verify initial state")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)

	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()

	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] Initial distribution: Staker=0, DevOps=0")

	println()
	println("[STEP 3] Skip 10 days to accumulate emissions (no minting)")
	println("[INFO] Skipping 864,000 seconds (10 days)...")
	testing.SkipHeights(864000)
	println("[INFO] Emissions accumulated for 10 days at 50/50 ratio")

	println()
	println("[STEP 4] Change distribution ratio to 80/20")
	println("[INFO] This should distribute accumulated emissions at OLD ratio (50/50)")
	testing.SetRealm(adminRealm)

	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000, // 80%
		emission.DEVOPS, 2000,           // 20%
		emission.COMMUNITY_POOL, 0,      // 0%
		emission.GOV_STAKER, 0,          // 0%
	)
	println("[INFO] Distribution ratio changed to 80/20")

	println()
	println("[STEP 5] Verify accumulated emissions were distributed at OLD ratio")
	stakerAfterRatioChange := emission.GetDistributedToStaker()
	devopsAfterRatioChange := emission.GetDistributedToDevOps()

	println(ufmt.Sprintf("[INFO] Distributed: Staker=%d, DevOps=%d",
		stakerAfterRatioChange, devopsAfterRatioChange))

	uassert.True(t, stakerAfterRatioChange > 0)
	uassert.True(t, devopsAfterRatioChange > 0)

	ratio := float64(stakerAfterRatioChange) / float64(devopsAfterRatioChange)
	println(ufmt.Sprintf("[INFO] Distribution ratio: %.2f", ratio))
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~1.0 (50/50), got %.2f", ratio))

	uassert.True(t, ratio > 0.9 && ratio < 1.1)
	println("[SUCCESS] Accumulated emissions distributed at OLD ratio (50/50)")

	println()
	println("[STEP 6] Skip 1 day and mint new emissions")
	testing.SkipHeights(86400)
	emission.MintAndDistributeGns(cross)

	println()
	println("[STEP 7] Verify new emissions use NEW ratio (80/20)")
	stakerAfterNew := emission.GetDistributedToStaker()
	devopsAfterNew := emission.GetDistributedToDevOps()

	stakerIncrement := stakerAfterNew - stakerAfterRatioChange
	devopsIncrement := devopsAfterNew - devopsAfterRatioChange

	println(ufmt.Sprintf("[INFO] New emissions: Staker=%d, DevOps=%d",
		stakerIncrement, devopsIncrement))

	if stakerIncrement > 0 && devopsIncrement > 0 {
		newRatio := float64(stakerIncrement) / float64(devopsIncrement)
		println(ufmt.Sprintf("[INFO] New emission ratio: %.2f", newRatio))
		println(ufmt.Sprintf("[EXPECTED] Ratio should be ~4.0 (80/20), got %.2f", newRatio))

		uassert.True(t, newRatio > 3.5 && newRatio < 4.5)
		println("[SUCCESS] New emissions use NEW ratio (80/20)")
	}

	println()
	println("[SCENARIO COMPLETE] No retroactive application verified")
	println("==========================================================")
}

// Output:
// [SCENARIO] Emission Distribution Ratio Change - No Retroactive Application
// ==============================================================================
//
// [STEP 1] Setup initial 50/50 distribution ratio
// [INFO] Distribution ratio set to 50/50 (Staker/DevOps)
//
// [STEP 2] Set distribution start time and verify initial state
// [INFO] Initial distribution: Staker=0, DevOps=0
//
// [STEP 3] Skip 10 days to accumulate emissions (no minting)
// [INFO] Skipping 864,000 seconds (10 days)...
// [INFO] Emissions accumulated for 10 days at 50/50 ratio
//
// [STEP 4] Change distribution ratio to 80/20
// [INFO] This should distribute accumulated emissions at OLD ratio (50/50)
// [INFO] Distribution ratio changed to 80/20
//
// [STEP 5] Verify accumulated emissions were distributed at OLD ratio
// [INFO] Distributed: Staker=15410605312201, DevOps=15410605312201
// [INFO] Distribution ratio: 1.00
// [EXPECTED] Ratio should be ~1.0 (50/50), got 1.00
// [SUCCESS] Accumulated emissions distributed at OLD ratio (50/50)
//
// [STEP 6] Skip 1 day and mint new emissions
//
// [STEP 7] Verify new emissions use NEW ratio (80/20)
// [INFO] New emissions: Staker=2465753356800, DevOps=616438339200
// [INFO] New emission ratio: 4.00
// [EXPECTED] Ratio should be ~4.0 (80/20), got 4.00
// [SUCCESS] New emissions use NEW ratio (80/20)
//
// [SCENARIO COMPLETE] No retroactive application verified
// ==========================================================
