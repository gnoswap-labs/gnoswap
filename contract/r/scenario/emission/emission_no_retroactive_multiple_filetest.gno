// Emission multiple ratio changes scenario test
// Scenario: Multiple distribution ratio changes over time
//
// Setup:
// - Period 1 (20 days): 70% Liquidity Staker, 30% DevOps
// - Period 2 (20 days): 60% Liquidity Staker, 40% DevOps
// - Period 3 (ongoing): 50% Liquidity Staker, 50% DevOps
//
// Expected Behavior:
// - Period 1 emissions should be distributed at 70/30 ratio
// - Period 2 emissions should be distributed at 60/40 ratio
// - Each period's emissions use their corresponding ratios, no retroactive effects

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
	println("[SCENARIO] Emission Distribution - Multiple Ratio Changes")
	println("==========================================================")
	println()

	testMultipleRatioChanges()
}

func testMultipleRatioChanges() {
	testing.SetRealm(adminRealm)

	println("[STEP 1] Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[STEP 2] Period 1 - Set 70/30 ratio")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000, // 70%
		emission.DEVOPS, 3000,           // 30%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Period 1 ratio: 70/30")

	println()
	println("[STEP 3] Skip 20 days (Period 1)")
	testing.SkipHeights(1728000)
	println("[INFO] Period 1: 20 days elapsed")

	println()
	println("[STEP 4] Change to 60/40 ratio (Period 2 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 6000, // 60%
		emission.DEVOPS, 4000,           // 40%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Period 2 ratio: 60/40")

	println()
	println("[STEP 5] Verify Period 1 distributions (70/30)")
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()

	println(ufmt.Sprintf("[INFO] Period 1 distributions: Staker=%d, DevOps=%d",
		period1Staker, period1Devops))

	uassert.True(t, period1Staker > 0)
	uassert.True(t, period1Devops > 0)

	ratio1 := float64(period1Staker) / float64(period1Devops)
	expectedRatio1 := 7000.0 / 3000.0 // 2.333...

	println(ufmt.Sprintf("[INFO] Period 1 ratio: %.2f", ratio1))
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~2.33 (70/30), got %.2f", ratio1))

	uassert.True(t, ratio1 > expectedRatio1*0.9 && ratio1 < expectedRatio1*1.1)
	println("[SUCCESS] Period 1 used 70/30 ratio")

	println()
	println("[STEP 6] Skip 20 days (Period 2)")
	testing.SkipHeights(1728000)
	println("[INFO] Period 2: 20 days elapsed")

	println()
	println("[STEP 7] Change to 50/50 ratio (Period 3 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Period 3 ratio: 50/50")

	println()
	println("[STEP 8] Verify Period 2 distributions (60/40)")
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()

	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops

	println(ufmt.Sprintf("[INFO] Period 2 distributions: Staker=%d, DevOps=%d",
		period2Staker, period2Devops))

	if period2Staker > 0 && period2Devops > 0 {
		ratio2 := float64(period2Staker) / float64(period2Devops)
		expectedRatio2 := 6000.0 / 4000.0 // 1.5

		println(ufmt.Sprintf("[INFO] Period 2 ratio: %.2f", ratio2))
		println(ufmt.Sprintf("[EXPECTED] Ratio should be ~1.5 (60/40), got %.2f", ratio2))

		uassert.True(t, ratio2 > expectedRatio2*0.9 && ratio2 < expectedRatio2*1.1)
		println("[SUCCESS] Period 2 used 60/40 ratio")
	}

	println()
	println("[SCENARIO COMPLETE] Multiple ratio changes handled correctly")
	println("===============================================================")
}

// Output:
// [SCENARIO] Emission Distribution - Multiple Ratio Changes
// ==========================================================
//
// [STEP 1] Set distribution start time
// [INFO] Distribution start time set
//
// [STEP 2] Period 1 - Set 70/30 ratio
// [INFO] Period 1 ratio: 70/30
//
// [STEP 3] Skip 20 days (Period 1)
// [INFO] Period 1: 20 days elapsed
//
// [STEP 4] Change to 60/40 ratio (Period 2 begins)
// [INFO] Period 2 ratio: 60/40
//
// [STEP 5] Verify Period 1 distributions (70/30)
// [INFO] Period 1 distributions: Staker=43150189309082, DevOps=18492938275320
// [INFO] Period 1 ratio: 2.33
// [EXPECTED] Ratio should be ~2.33 (70/30), got 2.33
// [SUCCESS] Period 1 used 70/30 ratio
//
// [STEP 6] Skip 20 days (Period 2)
// [INFO] Period 2: 20 days elapsed
//
// [STEP 7] Change to 50/50 ratio (Period 3 begins)
// [INFO] Period 3 ratio: 50/50
//
// [STEP 8] Verify Period 2 distributions (60/40)
// [INFO] Period 2 distributions: Staker=36986300352000, DevOps=24657533568000
// [INFO] Period 2 ratio: 1.50
// [EXPECTED] Ratio should be ~1.5 (60/40), got 1.50
// [SUCCESS] Period 2 used 60/40 ratio
//
// [SCENARIO COMPLETE] Multiple ratio changes handled correctly
// ===============================================================
