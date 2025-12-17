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

	println(ufmt.Sprintf("[INFO] Distributed: Staker=%d, DevOps=%d", stakerAfter, devopsAfter))

	uassert.True(t, stakerAfter > 0)
	uassert.True(t, devopsAfter > 0)

	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 8000.0 / 2000.0 // 4.0

	println(ufmt.Sprintf("[INFO] Distribution ratio: %.2f", ratio))
	println(ufmt.Sprintf("[EXPECTED] Ratio should be ~4.0 (80/20), got %.2f", ratio))

	uassert.True(t, ratio > expectedRatio*0.9 && ratio < expectedRatio*1.1)
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
// [INFO] Distributed: Staker=73972035635522, DevOps=18493008908880
// [INFO] Distribution ratio: 4.00
// [EXPECTED] Ratio should be ~4.0 (80/20), got 4.00
//
