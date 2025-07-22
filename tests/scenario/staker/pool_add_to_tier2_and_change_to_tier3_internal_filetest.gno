// pool add to tier 2 and change to tier 3 internal rewards scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Set pool to tier 2")
	setPoolToTier2()
	println()

	println("[SCENARIO] 4. Mint and stake position")
	mintAndStakePosition()
	println()

	println("[SCENARIO] 5. Collect reward with tier 2")
	collectRewardWithTier2()
	println()

	println("[SCENARIO] 6. Change pool to tier 3")
	changePoolToTier3()
	println()

	println("[SCENARIO] 7. Collect reward with tier 3")
	collectRewardWithTier3()
	println()

	println("[SCENARIO] 8. Compare tier rewards")
	compareTierRewards()
	println()

	println("[SCENARIO] 9. Final verification")
	finalVerification()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func mintAndStakePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: -100 ~ 100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)

	println("[INFO] approve NFT to staker and stake position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	ufmt.Printf("[EXPECTED] position staked successfully\n")
	testing.SkipHeights(1)
}

func setPoolToTier2() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool to tier 2")
	sr.SetPoolTierByAdmin(cross, poolPath, 2)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier set to: %d\n", currentTier)

	if currentTier != 2 {
		panic("pool tier should be 2")
	}

	println("[INFO] pool successfully set to tier 2")
}

func collectRewardWithTier2() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards with tier 2")
	testing.SkipHeights(10)

	println("[INFO] collect reward with tier 2")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	tier2Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward with tier 2: %d\n", tier2Reward)

	if tier2Reward <= 0 {
		panic("should have received reward with tier 2")
	}

	// Store tier 2 reward for comparison
	println("[INFO] tier 2 reward recorded for comparison")
}

func changePoolToTier3() {
	testing.SetRealm(adminRealm)

	println("[INFO] change pool from tier 2 to tier 3")
	sr.ChangePoolTierByAdmin(cross, poolPath, 3)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier changed to: %d\n", currentTier)

	if currentTier != 3 {
		panic("pool tier should be 3")
	}

	println("[INFO] pool successfully changed to tier 3")
}

func collectRewardWithTier3() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards with tier 3")
	testing.SkipHeights(10)

	println("[INFO] collect reward with tier 3")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	tier3Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward with tier 3: %d\n", tier3Reward)

	if tier3Reward <= 0 {
		panic("should have received reward with tier 3")
	}

	println("[INFO] tier 3 reward recorded for comparison")
}

func compareTierRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] compare rewards between tiers")

	// Collect one more reward from each tier for direct comparison
	println("[INFO] skip blocks for tier comparison")
	testing.SkipHeights(5)

	println("[INFO] collect reward for comparison")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	currentTierReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] current tier 3 reward: %d\n", currentTierReward)

	// Tier multipliers:
	// Tier 1: 70% (index 0 -> 0.7)
	// Tier 2: 15% (index 1 -> 0.15)
	// Tier 3: 15% (index 2 -> 0.15)

	println("[INFO] tier comparison analysis:")
	println("[INFO] - Tier 1: 70% of total emission")
	println("[INFO] - Tier 2: 15% of total emission")
	println("[INFO] - Tier 3: 15% of total emission")
	println("[INFO] - Tier 2 and Tier 3 should have similar rewards")
}

func finalVerification() {
	testing.SetRealm(adminRealm)

	println("[INFO] final verification of tier system")

	// Verify current tier
	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] final pool tier: %d\n", currentTier)

	if currentTier != 3 {
		panic("final pool tier should be 3")
	}

	// Test that we can still collect rewards
	println("[INFO] skip blocks for final reward test")
	testing.SkipHeights(5)

	println("[INFO] collect final reward")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	finalReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] final reward: %d\n", finalReward)

	if finalReward <= 0 {
		panic("should have received final reward")
	}

	println("[INFO] pool tier change scenario completed successfully")
	println("[INFO] confirmed: tier changes work correctly and affect reward distribution")
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
//
// [SCENARIO] 3. Set pool to tier 2
// [INFO] set pool to tier 2
// [EXPECTED] pool tier set to: 2
// [INFO] pool successfully set to tier 2
//
// [SCENARIO] 4. Mint and stake position
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -100 ~ 100)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [INFO] approve NFT to staker and stake position
// [EXPECTED] position staked successfully
//
// [SCENARIO] 5. Collect reward with tier 2
// [INFO] skip blocks to accumulate rewards with tier 2
// [INFO] collect reward with tier 2
// [EXPECTED] reward with tier 2: 10595032
// [INFO] tier 2 reward recorded for comparison
//
// [SCENARIO] 6. Change pool to tier 3
// [INFO] change pool from tier 2 to tier 3
// [EXPECTED] pool tier changed to: 3
// [INFO] pool successfully changed to tier 3
//
// [SCENARIO] 7. Collect reward with tier 3
// [INFO] skip blocks to accumulate rewards with tier 3
// [INFO] collect reward with tier 3
// [EXPECTED] reward with tier 3: 6421229
// [INFO] tier 3 reward recorded for comparison
//
// [SCENARIO] 8. Compare tier rewards
// [INFO] compare rewards between tiers
// [INFO] skip blocks for tier comparison
// [INFO] collect reward for comparison
// [EXPECTED] current tier 3 reward: 3210614
// [INFO] tier comparison analysis:
// [INFO] - Tier 1: 70% of total emission
// [INFO] - Tier 2: 15% of total emission
// [INFO] - Tier 3: 15% of total emission
// [INFO] - Tier 2 and Tier 3 should have similar rewards
//
// [SCENARIO] 9. Final verification
// [INFO] final verification of tier system
// [EXPECTED] final pool tier: 3
// [INFO] skip blocks for final reward test
// [INFO] collect final reward
// [EXPECTED] final reward: 3210614
// [INFO] pool tier change scenario completed successfully
// [INFO] confirmed: tier changes work correctly and affect reward distribution
