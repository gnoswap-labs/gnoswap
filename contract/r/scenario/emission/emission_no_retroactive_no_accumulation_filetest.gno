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
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()
	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] ratio set to 80/20 without accumulated emissions")
	println("[EXPECTED] no errors when changing ratio without accumulation")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 60 days")
	testing.SkipHeights(5184000)
	println("[INFO] 60 days elapsed")
	println()

	println("[SCENARIO] 4. Distribute accumulated emissions")
	emission.MintAndDistributeGns(cross)
	stakerAfter := emission.GetDistributedToStaker()
	devopsAfter := emission.GetDistributedToDevOps()
	println(ufmt.Sprintf("[INFO] distributed: Staker=%d, DevOps=%d",
		stakerAfter, devopsAfter))
	ratio := float64(stakerAfter) / float64(devopsAfter)
	expectedRatio := 8000.0 / 2000.0
	println(ufmt.Sprintf("[INFO] ratio: %.2f", ratio))
	println("[EXPECTED] all emissions use 80/20 ratio")
	uassert.True(t, stakerAfter > 0)
	uassert.True(t, devopsAfter > 0)
	uassert.True(t, ratio > expectedRatio*0.9 && ratio < expectedRatio*1.1)
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Change ratio to 80/20 without accumulation
// [INFO] ratio set to 80/20 without accumulated emissions
// [EXPECTED] no errors when changing ratio without accumulation
//
// [SCENARIO] 3. Accumulate emissions for 60 days
// [INFO] 60 days elapsed
//
// [SCENARIO] 4. Distribute accumulated emissions
// [INFO] distributed: Staker=147944636339522, DevOps=36986159084880
// [INFO] ratio: 4.00
// [EXPECTED] all emissions use 80/20 ratio
