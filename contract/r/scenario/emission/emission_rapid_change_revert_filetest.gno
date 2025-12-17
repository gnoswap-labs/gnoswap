// Emission rapid ratio change and revert scenario test
// Scenario: Change ratio then immediately revert to original
//
// Setup:
// - Initial ratio: 50/50
// - Accumulate for 10 days
// - Change to 90/10
// - Immediately revert to 50/50
// - Accumulate for another 10 days
//
// Expected Behavior:
// - First 10 days distributed at 50/50
// - Brief 90/10 period should distribute accumulated at 50/50
// - Next 10 days distributed at 50/50
// - Overall effect: all emissions at 50/50 (90/10 had no effect)

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
	testRapidChangeAndRevert()
}

func testRapidChangeAndRevert() {
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
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Initial ratio: 50/50")

	println()
	println("[SCENARIO] 3. Skip 10 days (Period 1)")
	testing.SkipHeights(864000) // 10 days
	println("[INFO] Period 1: 10 days elapsed at 50/50")

	println()
	println("[SCENARIO] 4. Temporarily change to 90/10")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 9000, // 90%
		emission.DEVOPS, 1000,           // 10%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Changed to 90/10")

	println()
	println("[SCENARIO] 5. Verify Period 1 was distributed at 50/50")
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()

	println(ufmt.Sprintf("[INFO] After ratio change: Staker=%d, DevOps=%d",
		period1Staker, period1Devops))

	ratio1 := float64(period1Staker) / float64(period1Devops)
	println(ufmt.Sprintf("[INFO] Ratio: %.2f", ratio1))
	println(ufmt.Sprintf("[EXPECTED] Should be ~1.0 (50/50), got %.2f", ratio1))

	uassert.True(t, ratio1 > 0.9 && ratio1 < 1.1)
	println()
	println("[SCENARIO] 6. Immediately revert to 50/50")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000, // 50%
		emission.DEVOPS, 5000,           // 50%
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] Reverted to 50/50")

	println()
	println("[SCENARIO] 7. Verify no additional distribution (90/10 period was empty)")
	revertStaker := emission.GetDistributedToStaker()
	revertDevops := emission.GetDistributedToDevOps()

	uassert.Equal(t, period1Staker, revertStaker)
	uassert.Equal(t, period1Devops, revertDevops)
	println("[INFO] No change in distributions (90/10 had no accumulated emissions)")
	println()
	println("[SCENARIO] 8. Skip another 10 days (Period 2)")
	testing.SkipHeights(864000) // 10 days
	println("[INFO] Period 2: 10 days elapsed at 50/50")

	println()
	println("[SCENARIO] 9. Mint final emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[SCENARIO] 10. Verify Period 2 also distributed at 50/50")
	finalStaker := emission.GetDistributedToStaker()
	finalDevops := emission.GetDistributedToDevOps()

	period2Staker := finalStaker - revertStaker
	period2Devops := finalDevops - revertDevops

	println(ufmt.Sprintf("[INFO] Period 2: Staker=%d, DevOps=%d",
		period2Staker, period2Devops))

	if period2Staker > 0 && period2Devops > 0 {
		ratio2 := float64(period2Staker) / float64(period2Devops)
		println(ufmt.Sprintf("[INFO] Period 2 ratio: %.2f", ratio2))
		println(ufmt.Sprintf("[EXPECTED] Should be ~1.0 (50/50), got %.2f", ratio2))

		uassert.True(t, ratio2 > 0.9 && ratio2 < 1.1)
	}

	println()
	println("[SCENARIO] 11. Verify overall distribution")
	overallRatio := float64(finalStaker) / float64(finalDevops)
	println(ufmt.Sprintf("[INFO] Overall ratio: %.2f", overallRatio))
	println(ufmt.Sprintf("[EXPECTED] Should be ~1.0 (50/50), got %.2f", overallRatio))

	uassert.True(t, overallRatio > 0.9 && overallRatio < 1.1)
	println()
}

// Output:
// [SCENARIO] 1. Set distribution start time
// [INFO] Distribution start time set
//
// [SCENARIO] 2. Set initial ratio to 50/50
// [INFO] Initial ratio: 50/50
//
// [SCENARIO] 3. Skip 10 days (Period 1)
// [INFO] Period 1: 10 days elapsed at 50/50
//
// [SCENARIO] 4. Temporarily change to 90/10
// [INFO] Changed to 90/10
//
// [SCENARIO] 5. Verify Period 1 was distributed at 50/50
// [INFO] After ratio change: Staker=15410605312201, DevOps=15410605312201
// [INFO] Ratio: 1.00
// [EXPECTED] Should be ~1.0 (50/50), got 1.00
//
// [SCENARIO] 6. Immediately revert to 50/50
// [INFO] Reverted to 50/50
//
// [SCENARIO] 7. Verify no additional distribution (90/10 period was empty)
// [INFO] No change in distributions (90/10 had no accumulated emissions)
//
// [SCENARIO] 8. Skip another 10 days (Period 2)
// [INFO] Period 2: 10 days elapsed at 50/50
//
// [SCENARIO] 9. Mint final emissions
// [INFO] MintAndDistributeGns called
//
// [SCENARIO] 10. Verify Period 2 also distributed at 50/50
// [INFO] Period 2: Staker=15410958480000, DevOps=15410958480000
// [INFO] Period 2 ratio: 1.00
// [EXPECTED] Should be ~1.0 (50/50), got 1.00
//
// [SCENARIO] 11. Verify overall distribution
// [INFO] Overall ratio: 1.00
// [EXPECTED] Should be ~1.0 (50/50), got 1.00
//
