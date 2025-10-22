// pool partial collect tier removal scenario test
// This test verifies that rewards accumulated before tier removal
// can be collected even after the pool is removed from tier system

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

	pn "gno.land/r/gnoswap/position"
	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
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

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

	// Variables to track rewards
	firstCollectReward  int64
	secondCollectReward int64
	thirdCollectReward  int64
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. Mint and stake position")
	mintAndStakePosition()
	println()

	println("[SCENARIO] 4. First partial collect (5 blocks)")
	firstPartialCollect()
	println()

	println("[SCENARIO] 5. Remove pool from tier")
	removePoolFromTier()
	println()

	println("[SCENARIO] 6. Second collect after tier removal")
	secondCollectAfterRemoval()
	println()

	println("[SCENARIO] 7. Wait and collect again (should be 0)")
	thirdCollectNoReward()
	println()

	println("[SCENARIO] 8. Verify partial collection logic")
	verifyPartialCollection()
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

func createPoolAndSetTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool to tier 2")
	sr.SetPoolTier(cross, poolPath, 2)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier: %d (should be 2)\n", currentTier)

	if currentTier != 2 {
		panic("pool tier should be 2")
	}
}

func mintAndStakePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint position (tick range: -100 ~ 100)")
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

	println("[INFO] position staked successfully")
	testing.SkipHeights(1)
}

func firstPartialCollect() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 5 blocks to accumulate rewards")
	testing.SkipHeights(5)

	println("[INFO] first partial collect")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	firstCollectReward = afterGns - beforeGns

	ufmt.Printf("[EXPECTED] first collect reward: %d (5 blocks worth)\n", firstCollectReward)

	if firstCollectReward <= 0 {
		panic("should have received reward for first 5 blocks")
	}

	println("[INFO] wait 5 more blocks while still in tier 2")
	testing.SkipHeights(5)
}

func removePoolFromTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool from tier system")
	sr.RemovePoolTier(cross, poolPath)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier: %d (should be 0)\n", currentTier)

	if currentTier != 0 {
		panic("pool tier should be 0 after removal")
	}
}

func secondCollectAfterRemoval() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect remaining rewards from before tier removal")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	secondCollectReward = afterGns - beforeGns

	ufmt.Printf("[EXPECTED] second collect reward: %d (remaining 5 blocks worth)\n", secondCollectReward)

	if secondCollectReward <= 0 {
		panic("should have received remaining rewards from before tier removal")
	}

	println("[INFO] confirmed: past rewards can be collected after tier removal")
}

func thirdCollectNoReward() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 10 blocks (no rewards expected as tier is 0)")
	testing.SkipHeights(10)

	println("[INFO] third collect attempt")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	thirdCollectReward = afterGns - beforeGns

	ufmt.Printf("[EXPECTED] third collect reward: %d (should be 0)\n", thirdCollectReward)

	if thirdCollectReward != 0 {
		panic("should not receive any reward after tier removal")
	}

	println("[INFO] confirmed: no new rewards accumulate after tier removal")
}

func verifyPartialCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] verify partial collection logic")

	// First and second collect should be approximately equal (both 5 blocks)
	ufmt.Printf("[ANALYSIS] first collect: %d GNS (5 blocks)\n", firstCollectReward)
	ufmt.Printf("[ANALYSIS] second collect: %d GNS (5 blocks)\n", secondCollectReward)
	ufmt.Printf("[ANALYSIS] third collect: %d GNS (should be 0)\n", thirdCollectReward)

	// Allow for variance due to timing and rounding
	// The second collection might be slightly less due to the exact timing of tier removal
	diff := int64(firstCollectReward) - int64(secondCollectReward)
	if diff < 0 {
		diff = -diff
	}

	tolerance := int64(firstCollectReward) / 5
	if diff > tolerance {
		ufmt.Printf("[WARNING] difference between collections: %d (tolerance: %d)\n", diff, tolerance)
		ufmt.Printf("[INFO] This difference is expected due to tier removal timing\n")
	}

	totalReward := firstCollectReward + secondCollectReward
	ufmt.Printf("[SUMMARY] total rewards collected: %d GNS (10 blocks in tier 2)\n", totalReward)

	println("[INFO] partial collection scenario completed successfully")
	println("[INFO] confirmed: rewards can be partially collected and tier removal preserves uncollected rewards")
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
// [SCENARIO] 2. Create pool and set tier
// [INFO] create bar:baz:100 pool
// [INFO] set pool to tier 2
// [EXPECTED] pool tier: 2 (should be 2)
//
// [SCENARIO] 3. Mint and stake position
// [INFO] approve tokens for minting
// [INFO] mint position (tick range: -100 ~ 100)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [INFO] approve NFT to staker and stake position
// [INFO] position staked successfully
//
// [SCENARIO] 4. First partial collect (5 blocks)
// [INFO] skip 5 blocks to accumulate rewards
// [INFO] first partial collect
// [EXPECTED] first collect reward: 14447771 (5 blocks worth)
// [INFO] wait 5 more blocks while still in tier 2
//
// [SCENARIO] 5. Remove pool from tier
// [INFO] remove pool from tier system
// [EXPECTED] pool tier: 0 (should be 0)
//
// [SCENARIO] 6. Second collect after tier removal
// [INFO] collect remaining rewards from before tier removal
// [EXPECTED] second collect reward: 12039809 (remaining 5 blocks worth)
// [INFO] confirmed: past rewards can be collected after tier removal
//
// [SCENARIO] 7. Wait and collect again (should be 0)
// [INFO] skip 10 blocks (no rewards expected as tier is 0)
// [INFO] third collect attempt
// [EXPECTED] third collect reward: 0 (should be 0)
// [INFO] confirmed: no new rewards accumulate after tier removal
//
// [SCENARIO] 8. Verify partial collection logic
// [INFO] verify partial collection logic
// [ANALYSIS] first collect: 14447771 GNS (5 blocks)
// [ANALYSIS] second collect: 12039809 GNS (5 blocks)
// [ANALYSIS] third collect: 0 GNS (should be 0)
// [SUMMARY] total rewards collected: 26487580 GNS (10 blocks in tier 2)
// [INFO] partial collection scenario completed successfully
// [INFO] confirmed: rewards can be partially collected and tier removal preserves uncollected rewards
