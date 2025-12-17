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
	testNoRetroactiveApplication()
}

func testNoRetroactiveApplication() {
	println("[SCENARIO] 1. Setup initial 50/50 distribution ratio")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 5000,
		emission.DEVOPS, 5000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	println("[INFO] distribution ratio set to 50/50 (Staker/DevOps)")
	println()

	println("[SCENARIO] 2. Set distribution start time")
	now := time.Now().Unix()
	emission.SetDistributionStartTime(cross, now+100)
	stakerBefore := emission.GetDistributedToStaker()
	devopsBefore := emission.GetDistributedToDevOps()
	uassert.Equal(t, int64(0), stakerBefore)
	uassert.Equal(t, int64(0), devopsBefore)
	println("[INFO] initial distribution: Staker=0, DevOps=0")
	println()

	println("[SCENARIO] 3. Accumulate emissions for 10 days (864,000 heights)")
	testing.SkipHeights(864000)
	println("[INFO] emissions accumulated without distribution")
	println()

	println("[SCENARIO] 4. Change distribution ratio to 80/20")
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(
		cross,
		emission.LIQUIDITY_STAKER, 8000,
		emission.DEVOPS, 2000,
		emission.COMMUNITY_POOL, 0,
		emission.GOV_STAKER, 0,
	)
	stakerAfterRatioChange := emission.GetDistributedToStaker()
	devopsAfterRatioChange := emission.GetDistributedToDevOps()
	println(ufmt.Sprintf("[INFO] distributed: Staker=%d, DevOps=%d",
		stakerAfterRatioChange, devopsAfterRatioChange))
	ratio := float64(stakerAfterRatioChange) / float64(devopsAfterRatioChange)
	println(ufmt.Sprintf("[INFO] ratio: %.2f", ratio))
	println("[EXPECTED] accumulated emissions distributed at OLD ratio (50/50)")
	uassert.True(t, stakerAfterRatioChange > 0)
	uassert.True(t, devopsAfterRatioChange > 0)
	uassert.True(t, ratio > 0.9 && ratio < 1.1)
	println()

	println("[SCENARIO] 5. Accumulate 1 more day and distribute")
	testing.SkipHeights(86400)
	emission.MintAndDistributeGns(cross)
	stakerAfterNew := emission.GetDistributedToStaker()
	devopsAfterNew := emission.GetDistributedToDevOps()
	stakerIncrement := stakerAfterNew - stakerAfterRatioChange
	devopsIncrement := devopsAfterNew - devopsAfterRatioChange
	println(ufmt.Sprintf("[INFO] new emissions: Staker=%d, DevOps=%d",
		stakerIncrement, devopsIncrement))
	newRatio := float64(stakerIncrement) / float64(devopsIncrement)
	println(ufmt.Sprintf("[INFO] ratio: %.2f", newRatio))
	println("[EXPECTED] new emissions use NEW ratio (80/20)")
	uassert.True(t, newRatio > 3.5 && newRatio < 4.5)
}

// Output:
// [SCENARIO] 1. Setup initial 50/50 distribution ratio
// [INFO] distribution ratio set to 50/50 (Staker/DevOps)
//
// [SCENARIO] 2. Set distribution start time
// [INFO] initial distribution: Staker=0, DevOps=0
//
// [SCENARIO] 3. Accumulate emissions for 10 days (864,000 heights)
// [INFO] emissions accumulated without distribution
//
// [SCENARIO] 4. Change distribution ratio to 80/20
// [INFO] distributed: Staker=15410605312201, DevOps=15410605312201
// [INFO] ratio: 1.00
// [EXPECTED] accumulated emissions distributed at OLD ratio (50/50)
//
// [SCENARIO] 5. Accumulate 1 more day and distribute
// [INFO] new emissions: Staker=2465753356800, DevOps=616438339200
// [INFO] ratio: 4.00
// [EXPECTED] new emissions use NEW ratio (80/20)
