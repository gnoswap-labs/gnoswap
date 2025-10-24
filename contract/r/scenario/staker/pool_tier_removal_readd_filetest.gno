// pool tier removal and re-addition scenario test
// This test verifies that:
// 1. Historical rewards are preserved when a pool is removed from tier
// 2. No new rewards accumulate while pool is out of tier system
// 3. New rewards start accumulating when pool is re-added to tier
// 4. Multiple removal and re-addition cycles work correctly

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	_ "gno.land/r/onbloc/obl"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	oblPath = "gno.land/r/onbloc/obl"

	fee100 uint32 = 100
	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath  = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
	pool2Path = "gno.land/r/onbloc/foo:gno.land/r/onbloc/obl:500"

	// Variables to track rewards during each phase
	firstTierRewards     int64
	removedPhaseRewards  int64
	secondTierRewards    int64
	secondRemovalRewards int64
	thirdTierRewards     int64
)

func main() {
	println("[SCENARIO] Test: Pool Tier Removal and Re-addition")
	println()

	println("[SCENARIO 1] Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO 2] Create pools and mint position")
	createPoolsAndMintPosition()
	println()

	println("[SCENARIO 3] First tier period - accumulate rewards")
	firstTierPeriod()
	println()

	println("[SCENARIO 4] Remove pool from tier - verify no new rewards")
	removeFromTierVerifyNoNewRewards()
	println()

	println("[SCENARIO 5] Re-add to tier - verify new rewards accumulate")
	reAddToTierVerifyNewRewards()
	println()

	println("[SCENARIO 6] Second removal - test multiple cycles")
	secondRemovalCycle()
	println()

	println("[SCENARIO 7] Final re-addition - verify complete cycle")
	finalReAdditionCycle()
	println()

	println("[SCENARIO 8] Verify complete scenario")
	verifyCompleteScenario()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPoolsAndMintPosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] create main test pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] create additional pool for tier system")
	pl.CreatePool(cross, fooPath, oblPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)

	println("[INFO] set initial tiers - main pool to tier 2, second pool to tier 1")
	sr.SetPoolTier(cross, poolPath, 2)
	sr.SetPoolTier(cross, pool2Path, 1)

	tier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[VERIFY] main pool initial tier: %d (expected: 2)\n", tier)

	if tier != 2 {
		panic("pool should start at tier 2")
	}

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint position (tick range: -200 ~ 200)")
	tokenId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-200),
		int32(200),
		"2000",
		"2000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[VERIFY] position ID: %d, liquidity: %s\n", tokenId, liquidity)

	println("[INFO] approve NFT to staker and stake position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(tokenId))
	sr.StakeToken(cross, tokenId, "")

	println("[SUCCESS] position staked successfully")
}

func firstTierPeriod() {
	testing.SetRealm(adminRealm)

	println("[INFO] accumulate rewards for 10 blocks in tier 2")
	testing.SkipHeights(10)

	println("[INFO] collect rewards while in tier 2")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	firstTierRewards = afterGns - beforeGns

	ufmt.Printf("[RESULT] first tier period rewards: %d GNS (10 blocks)\n", firstTierRewards)

	if firstTierRewards <= 0 {
		panic("should have received rewards in tier 2")
	}
}

func removeFromTierVerifyNoNewRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool from tier system")
	sr.RemovePoolTier(cross, poolPath)

	tier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[VERIFY] pool tier after removal: %d (expected: 0)\n", tier)

	if tier != 0 {
		panic("pool should be removed from tier system")
	}

	println("[INFO] skip 10 blocks while pool is out of tier system")
	testing.SkipHeights(10)

	println("[INFO] attempt to collect rewards - should get only historical rewards if any")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	removedPhaseRewards = afterGns - beforeGns

	ufmt.Printf("[RESULT] rewards while removed from tier: %d GNS (should be 0 or minimal)\n", removedPhaseRewards)

	if removedPhaseRewards > 0 {
		println("[INFO] collected remaining historical rewards")
	} else {
		println("[SUCCESS] no new rewards accumulated while out of tier system")
	}
}

func reAddToTierVerifyNewRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] re-add pool to tier system as tier 3")
	sr.SetPoolTier(cross, poolPath, 3)

	tier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[VERIFY] pool tier after re-addition: %d (expected: 3)\n", tier)

	if tier != 3 {
		panic("pool should be in tier 3")
	}

	println("[INFO] accumulate rewards for 10 blocks in tier 3")
	testing.SkipHeights(10)

	println("[INFO] collect rewards while in tier 3")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	secondTierRewards = afterGns - beforeGns

	ufmt.Printf("[RESULT] second tier period rewards: %d GNS (10 blocks in tier 3)\n", secondTierRewards)

	if secondTierRewards <= 0 {
		panic("should have received rewards after re-adding to tier")
	}

	println("[SUCCESS] new rewards accumulating after re-addition to tier system")
}

func secondRemovalCycle() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool from tier system again (second removal)")
	sr.RemovePoolTier(cross, poolPath)

	tier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[VERIFY] pool tier after second removal: %d (expected: 0)\n", tier)

	if tier != 0 {
		panic("pool should be removed from tier system")
	}

	println("[INFO] skip 5 blocks while pool is out of tier system")
	testing.SkipHeights(5)

	println("[INFO] attempt to collect rewards during second removal")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	secondRemovalRewards = afterGns - beforeGns

	ufmt.Printf("[RESULT] rewards during second removal: %d GNS (should be minimal)\n", secondRemovalRewards)

	println("[INFO] verify no new rewards accumulate during second removal period")
}

func finalReAdditionCycle() {
	testing.SetRealm(adminRealm)

	println("[INFO] re-add pool to tier 1 (highest tier)")
	sr.SetPoolTier(cross, poolPath, 1)

	tier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[VERIFY] pool tier after final re-addition: %d (expected: 1)\n", tier)

	if tier != 1 {
		panic("pool should be in tier 1")
	}

	println("[INFO] accumulate rewards for 10 blocks in tier 1")
	testing.SkipHeights(10)

	println("[INFO] collect rewards while in tier 1")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	thirdTierRewards = afterGns - beforeGns

	ufmt.Printf("[RESULT] third tier period rewards: %d GNS (10 blocks in tier 1)\n", thirdTierRewards)

	if thirdTierRewards <= 0 {
		panic("should have received rewards in tier 1")
	}

	println("[SUCCESS] rewards accumulating correctly after multiple removal/re-addition cycles")
}

func verifyCompleteScenario() {
	testing.SetRealm(adminRealm)

	println("[INFO] Complete reward history:")
	ufmt.Printf("  - First tier period (tier 2): %d GNS\n", firstTierRewards)
	ufmt.Printf("  - First removal period: %d GNS\n", removedPhaseRewards)
	ufmt.Printf("  - Second tier period (tier 3): %d GNS\n", secondTierRewards)
	ufmt.Printf("  - Second removal period: %d GNS\n", secondRemovalRewards)
	ufmt.Printf("  - Third tier period (tier 1): %d GNS\n", thirdTierRewards)

	totalActiveRewards := firstTierRewards + secondTierRewards + thirdTierRewards
	totalRemovalRewards := removedPhaseRewards + secondRemovalRewards

	ufmt.Printf("[INFO] Total active tier rewards: %d GNS\n", totalActiveRewards)
	ufmt.Printf("[INFO] Total removal period rewards: %d GNS\n", totalRemovalRewards)

	// Verify tier 1 > tier 2 > tier 3 (based on emission share)
	// Tier 1 gets 50%, Tier 2 gets 30%, Tier 3 gets 20% of emissions
	if thirdTierRewards <= firstTierRewards {
		println("[WARNING] Tier 1 rewards not higher than Tier 2 (may be due to pool count differences)")
	}

	if firstTierRewards <= secondTierRewards {
		println("[WARNING] Tier 2 rewards not higher than Tier 3 (may be due to pool count differences)")
	}

	// Verify minimal rewards during removal periods
	if totalRemovalRewards > totalActiveRewards/100 {
		println("[WARNING] Removal period rewards seem too high")
	}
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
// [SCENARIO] Test: Pool Tier Removal and Re-addition
//
// [SCENARIO 1] Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO 2] Create pools and mint position
// [INFO] create main test pool
// [INFO] create additional pool for tier system
// [INFO] set initial tiers - main pool to tier 2, second pool to tier 1
// [VERIFY] main pool initial tier: 2 (expected: 2)
// [INFO] approve tokens for minting
// [INFO] mint position (tick range: -200 ~ 200)
// [VERIFY] position ID: 1, liquidity: 201011
// [INFO] approve NFT to staker and stake position
// [SUCCESS] position staked successfully
//
// [SCENARIO 3] First tier period - accumulate rewards
// [INFO] accumulate rewards for 10 blocks in tier 2
// [INFO] collect rewards while in tier 2
// [RESULT] first tier period rewards: 24079619 GNS (10 blocks)
//
// [SCENARIO 4] Remove pool from tier - verify no new rewards
// [INFO] remove pool from tier system
// [VERIFY] pool tier after removal: 0 (expected: 0)
// [INFO] skip 10 blocks while pool is out of tier system
// [INFO] attempt to collect rewards - should get only historical rewards if any
// [RESULT] rewards while removed from tier: 0 GNS (should be 0 or minimal)
// [SUCCESS] no new rewards accumulated while out of tier system
//
// [SCENARIO 5] Re-add to tier - verify new rewards accumulate
// [INFO] re-add pool to tier system as tier 3
// [VERIFY] pool tier after re-addition: 3 (expected: 3)
// [INFO] accumulate rewards for 10 blocks in tier 3
// [INFO] collect rewards while in tier 3
// [RESULT] second tier period rewards: 16053074 GNS (10 blocks in tier 3)
// [SUCCESS] new rewards accumulating after re-addition to tier system
//
// [SCENARIO 6] Second removal - test multiple cycles
// [INFO] remove pool from tier system again (second removal)
// [VERIFY] pool tier after second removal: 0 (expected: 0)
// [INFO] skip 5 blocks while pool is out of tier system
// [INFO] attempt to collect rewards during second removal
// [RESULT] rewards during second removal: 0 GNS (should be minimal)
// [INFO] verify no new rewards accumulate during second removal period
//
// [SCENARIO 7] Final re-addition - verify complete cycle
// [INFO] re-add pool to tier 1 (highest tier)
// [VERIFY] pool tier after final re-addition: 1 (expected: 1)
// [INFO] accumulate rewards for 10 blocks in tier 1
// [INFO] collect rewards while in tier 1
// [RESULT] third tier period rewards: 26755124 GNS (10 blocks in tier 1)
// [SUCCESS] rewards accumulating correctly after multiple removal/re-addition cycles
//
// [SCENARIO 8] Verify complete scenario
// [INFO] Complete reward history:
//   - First tier period (tier 2): 24079619 GNS
//   - First removal period: 0 GNS
//   - Second tier period (tier 3): 16053074 GNS
//   - Second removal period: 0 GNS
//   - Third tier period (tier 1): 26755124 GNS
// [INFO] Total active tier rewards: 66887817 GNS
// [INFO] Total removal period rewards: 0 GNS
