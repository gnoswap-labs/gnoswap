// pool add to tier 2 and removed internal rewards scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

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

	println("[SCENARIO] 6. Remove pool from tier system")
	removePoolFromTier()
	println()

	println("[SCENARIO] 7. Collect reward after tier removal")
	collectRewardAfterTierRemoval()
	println()

	println("[SCENARIO] 8. Verify pool removal effects")
	verifyPoolRemovalEffects()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
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
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
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
		maxTimeout,
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

	println("[INFO] confirmed: rewards are distributed with tier 2")
}

func removePoolFromTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool from tier system")
	sr.RemovePoolTierByAdmin(cross, poolPath)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier after removal: %d (should be 0)\n", currentTier)

	if currentTier != 0 {
		panic("pool tier should be 0 after removal")
	}

	println("[INFO] pool successfully removed from tier system")
}

func collectRewardAfterTierRemoval() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to test rewards after tier removal")
	testing.SkipHeights(10)

	println("[INFO] collect reward after tier removal")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	rewardAfterRemoval := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after tier removal: %d (should be 0)\n", rewardAfterRemoval)

	if rewardAfterRemoval != 0 {
		panic("should not receive reward after tier removal")
	}

	println("[INFO] confirmed: no rewards after tier removal")
}

func verifyPoolRemovalEffects() {
	testing.SetRealm(adminRealm)

	println("[INFO] verify pool removal effects")

	// Verify tier is still 0
	finalTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] final pool tier: %d (should be 0)\n", finalTier)

	if finalTier != 0 {
		panic("final pool tier should be 0")
	}

	// Test adding back to tier system
	println("[INFO] test adding pool back to tier system")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	restoredTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] restored pool tier: %d\n", restoredTier)

	if restoredTier != 1 {
		panic("restored pool tier should be 1")
	}

	println("[INFO] skip blocks to test rewards after restoration")
	testing.SkipHeights(5)

	println("[INFO] collect reward after tier restoration")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	rewardAfterRestoration := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after tier restoration: %d\n", rewardAfterRestoration)

	if rewardAfterRestoration <= 0 {
		panic("should receive reward after tier restoration")
	}

	println("[INFO] pool tier removal and restoration scenario completed successfully")
	println("[INFO] confirmed: tier removal stops rewards, tier restoration resumes rewards")
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
// [INFO] confirmed: rewards are distributed with tier 2
//
// [SCENARIO] 6. Remove pool from tier system
// [INFO] remove pool from tier system
// [EXPECTED] pool tier after removal: 0 (should be 0)
// [INFO] pool successfully removed from tier system
//
// [SCENARIO] 7. Collect reward after tier removal
// [INFO] skip blocks to test rewards after tier removal
// [INFO] collect reward after tier removal
// [EXPECTED] reward after tier removal: 0 (should be 0)
// [INFO] confirmed: no rewards after tier removal
//
// [SCENARIO] 8. Verify pool removal effects
// [INFO] verify pool removal effects
// [EXPECTED] final pool tier: 0 (should be 0)
// [INFO] test adding pool back to tier system
// [EXPECTED] restored pool tier: 1
// [INFO] skip blocks to test rewards after restoration
// [INFO] collect reward after tier restoration
// [EXPECTED] reward after tier restoration: 8026540
// [INFO] pool tier removal and restoration scenario completed successfully
// [INFO] confirmed: tier removal stops rewards, tier restoration resumes rewards
