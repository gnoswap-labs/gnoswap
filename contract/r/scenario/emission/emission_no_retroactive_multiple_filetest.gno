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
	testMultipleRatioChanges()
}

func testMultipleRatioChanges() {
	testing.SetRealm(adminRealm)

	println("[SCENARIO] 1. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	println()

	println("[SCENARIO] 2. Set Period 1 ratio (70/30)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 7000,
		emission.DEVOPS, 3000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] period 1 ratio set to 70/30")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 20 days (Period 1)")
	testing.SkipHeights(1728000)
	println("[INFO] period 1: 20 days elapsed")
	println()

	println("[SCENARIO] 4. Change to 60/40 ratio (Period 2 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 6000,
		emission.DEVOPS, 4000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	period1Staker := emission.GetDistributedToStaker()
	period1Devops := emission.GetDistributedToDevOps()
	println(ufmt.Sprintf("[INFO] period 1 distributed: Staker=%d, DevOps=%d",
		period1Staker, period1Devops))
	ratio1 := float64(period1Staker) / float64(period1Devops)
	expectedRatio1 := 7000.0 / 3000.0
	println(ufmt.Sprintf("[INFO] period 1 ratio: %.2f", ratio1))
	println("[EXPECTED] period 1 used 70/30 ratio")
	uassert.True(t, period1Staker > 0)
	uassert.True(t, period1Devops > 0)
	uassert.True(t, ratio1 > expectedRatio1*0.9 && ratio1 < expectedRatio1*1.1)
	println()

	println("[SCENARIO] 5. Accumulate emissions for 20 days (Period 2)")
	testing.SkipHeights(1728000)
	println("[INFO] period 2: 20 days elapsed")
	println()

	println("[SCENARIO] 6. Change to 50/50 ratio (Period 3 begins)")
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000,
		emission.DEVOPS, 5000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	totalStaker := emission.GetDistributedToStaker()
	totalDevops := emission.GetDistributedToDevOps()
	period2Staker := totalStaker - period1Staker
	period2Devops := totalDevops - period1Devops
	println(ufmt.Sprintf("[INFO] period 2 distributed: Staker=%d, DevOps=%d",
		period2Staker, period2Devops))
	ratio2 := float64(period2Staker) / float64(period2Devops)
	expectedRatio2 := 6000.0 / 4000.0
	println(ufmt.Sprintf("[INFO] period 2 ratio: %.2f", ratio2))
	println("[EXPECTED] period 2 used 60/40 ratio")
	uassert.True(t, ratio2 > expectedRatio2*0.9 && ratio2 < expectedRatio2*1.1)
}

// Output:
// [SCENARIO] 1. Set distribution start time
//
// [SCENARIO] 2. Set Period 1 ratio (70/30)
// [INFO] period 1 ratio set to 70/30
//
// [SCENARIO] 3. Accumulate emissions for 20 days (Period 1)
// [INFO] period 1: 20 days elapsed
//
// [SCENARIO] 4. Change to 60/40 ratio (Period 2 begins)
// [INFO] period 1 distributed: Staker=43150189309082, DevOps=18492938275320
// [INFO] period 1 ratio: 2.33
// [EXPECTED] period 1 used 70/30 ratio
//
// [SCENARIO] 5. Accumulate emissions for 20 days (Period 2)
// [INFO] period 2: 20 days elapsed
//
// [SCENARIO] 6. Change to 50/50 ratio (Period 3 begins)
// [INFO] period 2 distributed: Staker=36986300352000, DevOps=24657533568000
// [INFO] period 2 ratio: 1.50
// [EXPECTED] period 2 used 60/40 ratio
