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
	println("[SCENARIO] Emission Distribution - Ratio Change Without Accumulation")
	println("====================================================================")
	println()

	testRatioChangeWithoutAccumulation()
}

func testRatioChangeWithoutAccumulation() {
	testing.SetRealm(adminRealm)

	println("[STEP 1] Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[STEP 2] Immediately change ratio to 80/20 (no accumulated emissions)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000, // 80%
		emission.DEVOPS, 2000,           // 20%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Ratio set to 80/20 without any accumulated emissions")

	println()
	println("[STEP 3] Verify no errors and initial state is zero")
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()

	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] Initial distribution: Staker=0, DevOps=0")
	println("[SUCCESS] Ratio change without accumulation succeeded")

	println()
	println("[STEP 4] Skip 60 days to accumulate emissions")
	testing.SkipHeights(5184000)
	println("[INFO] Skipped 5,184,000 seconds (60 days)")

	println()
	println("[STEP 5] Mint accumulated emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[STEP 6] Verify all emissions use the 80/20 ratio")
	stakerAfter := emission.GetDistributedToStaker()
	devopsAfter := emission.GetDistributedToDevOps()

	println(ufmt.Sprintf("[INFO] Distributed: Staker=%d, DevOps=%d",
		stakerAfter, devopsAfter))

	uassert.True(t, stakerAfter > 0)
	uassert.True(t, devopsAfter > 0)

	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 8000.0 / 2000.0 // 4.0

	println(ufmt.Sprintf("[INFO] Distribution ratio: %.2f", ratio))
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~4.0 (80/20), got %.2f", ratio))

	uassert.True(t, ratio > expectedRatio*0.9 && ratio < expectedRatio*1.1)
	println("[SUCCESS] All emissions distributed at 80/20 ratio")

	println()
	println("[SCENARIO COMPLETE] Ratio change without accumulation verified")
	println("================================================================")
}

// Output:
// [SCENARIO] Emission Distribution - Ratio Change Without Accumulation
// ====================================================================
//
// [STEP 1] Set distribution start time
// [INFO] Distribution start time set
//
// [STEP 2] Immediately change ratio to 80/20 (no accumulated emissions)
// [INFO] Ratio set to 80/20 without any accumulated emissions
//
// [STEP 3] Verify no errors and initial state is zero
// [INFO] Initial distribution: Staker=0, DevOps=0
// [SUCCESS] Ratio change without accumulation succeeded
//
// [STEP 4] Skip 60 days to accumulate emissions
// [INFO] Skipped 5,184,000 seconds (60 days)
//
// [STEP 5] Mint accumulated emissions
// [INFO] MintAndDistributeGns called
//
// [STEP 6] Verify all emissions use the 80/20 ratio
// [INFO] Distributed: Staker=147944636339522, DevOps=36986159084880
// [INFO] Distribution ratio: 4.00
// [EXPECTED] Ratio should be ~4.0 (80/20), got 4.00
// [SUCCESS] All emissions distributed at 80/20 ratio
//
// [SCENARIO COMPLETE] Ratio change without accumulation verified
// ================================================================
