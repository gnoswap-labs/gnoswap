// Emission zero recipient scenario test
// Scenario: Change some recipients to 0% while others remain active
//
// Setup:
// - Period 1: All recipients get tokens (Staker 40%, DevOps 30%, Community 30%)
// - Accumulate for 15 days
// - Period 2: Change to exclude some recipients (Staker 100%, others 0%)
//
// Expected Behavior:
// - Period 1 emissions distributed to all recipients per their ratios
// - Period 2 emissions go only to active recipients (Staker 100%)
// - Recipients with 0% receive nothing in Period 2

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
	testZeroRecipientScenario()
}

func testZeroRecipientScenario() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println("[INFO] Distribution start time set")

	println()
	println("[SCENARIO] 2. Period 1 - All recipients active (40% Staker, 30% DevOps, 30% Community)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 4000, // 40%
		emission.DEVOPS, 3000,           // 30%
		emission.COMMUNITY_POOL, 3000,   // 30%
		emission.GOV_STAKER, 0,          // 0%
	)
	println("[INFO] Period 1 ratios: Staker=40%, DevOps=30%, Community=30%")

	println()
	println("[SCENARIO] 3. Skip 15 days (Period 1)")
	testing.SkipHeights(1296000) // 15 days
	println("[INFO] Period 1: 15 days elapsed")

	println()
	println("[SCENARIO] 4. Change to exclude DevOps and Community (Staker 100%)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 10000, // 100%
		emission.DEVOPS, 0,               // 0%
		emission.COMMUNITY_POOL, 0,       // 0%
		emission.GOV_STAKER, 0,           // 0%
	)
	println("[INFO] Period 2 ratios: Staker=100%, DevOps=0%, Community=0%")

	println()
	println("[SCENARIO] 5. Verify Period 1 distributions (all recipients)")
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	period1Community := emission.GetDistributedToCommunityPool()

	println(ufmt.Sprintf("[INFO] Period 1: Staker=%d, DevOps=%d, Community=%d",
		period1Staker, period1Devops, period1Community))

	uassert.True(t, period1Staker > 0)
	uassert.True(t, period1Devops > 0)
	uassert.True(t, period1Community > 0)

	stakerDevopsRatio := float64(period1Staker) / float64(period1Devops)
	println(ufmt.Sprintf("[INFO] Period 1 Staker/DevOps ratio: %.2f", stakerDevopsRatio))
	println(ufmt.Sprintf("[EXPECTED] Should be ~1.33 (40/30), got %.2f", stakerDevopsRatio))

	uassert.True(t, stakerDevopsRatio > 1.2 && stakerDevopsRatio < 1.5)
	println()
	println("[SCENARIO] 6. Skip 15 days (Period 2)")
	testing.SkipHeights(1296000) // 15 days
	println("[INFO] Period 2: 15 days elapsed")

	println()
	println("[SCENARIO] 7. Mint new emissions")
	emission.MintAndDistributeGns(cross)
	println("[INFO] MintAndDistributeGns called")

	println()
	println("[SCENARIO] 8. Verify Period 2 distributions (only Staker)")
	period2Staker := emission.GetDistributedToStaker() - period1Staker
	period2Devops := emission.GetDistributedToDevOps() - period1Devops
	period2Community := emission.GetDistributedToCommunityPool() - period1Community

	println(ufmt.Sprintf("[INFO] Period 2: Staker=%d, DevOps=%d, Community=%d",
		period2Staker, period2Devops, period2Community))

	uassert.True(t, period2Staker > 0)
	uassert.Equal(t, int64(0), period2Devops)
	uassert.Equal(t, int64(0), period2Community)
	println()
}

// Output:
// [SCENARIO] 1. Set distribution start time
// [INFO] Distribution start time set
//
// [SCENARIO] 2. Period 1 - All recipients active (40% Staker, 30% DevOps, 30% Community)
// [INFO] Period 1 ratios: Staker=40%, DevOps=30%, Community=30%
//
// [SCENARIO] 3. Skip 15 days (Period 1)
// [INFO] Period 1: 15 days elapsed
//
// [SCENARIO] 4. Change to exclude DevOps and Community (Staker 100%)
// [INFO] Period 2 ratios: Staker=100%, DevOps=0%, Community=0%
//
// [SCENARIO] 5. Verify Period 1 distributions (all recipients)
// [INFO] Period 1: Staker=18492867641761, DevOps=13869650731320, Community=13869650731320
// [INFO] Period 1 Staker/DevOps ratio: 1.33
// [EXPECTED] Should be ~1.33 (40/30), got 1.33
//
// [SCENARIO] 6. Skip 15 days (Period 2)
// [INFO] Period 2: 15 days elapsed
//
// [SCENARIO] 7. Mint new emissions
// [INFO] MintAndDistributeGns called
//
// [SCENARIO] 8. Verify Period 2 distributions (only Staker)
// [INFO] Period 2: Staker=46232875440002, DevOps=0, Community=0
//
