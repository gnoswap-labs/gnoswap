// pool tier removal and re-addition scenario test
// This test verifies that:
// 1. Historical rewards are preserved when a pool is removed from tier
// 2. No new rewards accumulate while pool is out of tier system
// 3. New rewards start accumulating when pool is re-added to tier
// 4. Multiple removal and re-addition cycles work correctly

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
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
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

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
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	oblPath = "gno.land/r/onbloc/obl"

	fee100 uint32 = 100
	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	barBazPoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

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

	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pools(Tier 1) and mint position")
	createPoolsAndMintPosition()
	println()

	println("[SCENARIO] 3. Skip warmup period")
	collectEmissionRewardsWithSkipHeights(86400 * 30)
	println()

	println("[SCENARIO] 4. Check tier 1 reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)")
	println("[SCENARIO] 4.1. Set pool tier to tier 1")
	setPoolTier(1)
	println()

	println("[SCENARIO] 4.2. Collect emission rewards in tier 1 with after 10 blocks")
	collectEmissionRewardsWithSkipHeights(10)
	println()

	println("[SCENARIO] 5. Check non-tier reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)")
	println("[SCENARIO] 5.1. Remove pool tier from tier 1")
	setPoolTier(0)
	println()

	println("[SCENARIO] 5.2. Collect emission rewards in non-tier with after 10 blocks")
	collectEmissionRewardsWithSkipHeights(10)
	println()

	println("[SCENARIO] 6. Check tier 2 reward (tier 1: 70%, tier 2: 30%, tier 3: 0%)")
	println("[SCENARIO] 6.1. Set pool tier to tier 2")
	setPoolTier(2)
	println()

	println("[SCENARIO] 6.2. Collect emission rewards in tier 2 with after 10 blocks")
	collectEmissionRewardsWithSkipHeights(10)
	println()

	println("[SCENARIO] 6.3. Skip 10 blocks to rewards")
	skipBlocks(10)
	println()

	println("[SCENARIO] 7. Check non-tier reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)")
	println("[SCENARIO] 7.1. Remove pool tier from tier 2")
	setPoolTier(0)
	skipBlocks(10)
	println()

	println("[SCENARIO] 8. Check tier 3 reward (tier 1: 80%, tier 2: 0%, tier 3: 20%)")
	println("[SCENARIO] 8.1. Set pool tier to tier 3")
	setPoolTier(3)
	println()

	println("[SCENARIO] 8.2. Collect emission rewards in tier 3 with after 10 blocks and tier2 10 blocks")
	collectEmissionRewardsWithSkipHeights(10)
	println()
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

	testing.SkipHeights(1)

	setPoolTier(1)

	tier := sr.GetPoolTier(barBazPoolPath)
	ufmt.Printf("[VERIFY] main pool initial tier: %d\n", tier)

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

	println("[EXPECTED] staked position ID:", tokenId)
}

func setPoolTier(tier int) {
	testing.SetRealm(adminRealm)

	beforePoolTier := sr.GetPoolTier(barBazPoolPath)
	beforePoolEmissionReward := int64(0)
	if beforePoolTier != 0 {
		beforePoolEmissionReward = sr.GetPoolReward(beforePoolTier)
	}

	sr.SetPoolTier(cross, barBazPoolPath, uint64(tier))

	afterPoolTier := sr.GetPoolTier(barBazPoolPath)
	afterPoolEmissionReward := int64(0)
	if afterPoolTier != 0 {
		afterPoolEmissionReward = sr.GetPoolReward(afterPoolTier)
	}

	ufmt.Printf("[EXPECTED] %s pool's tier changed: %d -> %d\n", barBazPoolPath, beforePoolTier, afterPoolTier)
	ufmt.Printf("[EXPECTED] %s pool's emission reward changed: %d -> %d\n", barBazPoolPath, beforePoolEmissionReward, afterPoolEmissionReward)
}

func collectEmissionRewardsWithSkipHeights(skippedHeights int64) {
	testing.SetRealm(adminRealm)

	currentPoolTier := sr.GetPoolTier(barBazPoolPath)
	ufmt.Printf("[INFO] pool tier: %d\n", currentPoolTier)

	skipBlocks(skippedHeights)

	// collect rewards to get collected GNS amount
	beforeGnsBalance := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGnsBalance := gns.BalanceOf(adminUser)
	collectedGns := afterGnsBalance - beforeGnsBalance

	ufmt.Printf("[EXPECTED] collected GNS amount: %d GNS\n", collectedGns)

	beforeTime := time.Now().Unix()
	skipBlocks(1)
	afterTime := time.Now().Unix()

	// collect rewards again to get reward amount per height
	beforeGnsBalance = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGnsBalance = gns.BalanceOf(adminUser)
	rewardPerHeight := afterGnsBalance - beforeGnsBalance

	ufmt.Printf("[EXPECTED] reward amount per second: %d GNS\n", rewardPerHeight/(afterTime-beforeTime))
}

func skipBlocks(skippedHeights int64) {
	ufmt.Printf("[INFO] skip %d blocks, current height: %d, current time: %d\n", skippedHeights, runtime.ChainHeight(), time.Now().Unix())
	testing.SkipHeights(skippedHeights)
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
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pools(Tier 1) and mint position
// [INFO] create main test pool
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 0 -> 1
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 0 -> 2675513
// [VERIFY] main pool initial tier: 1
// [INFO] approve tokens for minting
// [INFO] mint position (tick range: -200 ~ 200)
// [VERIFY] position ID: 1, liquidity: 201011
// [INFO] approve NFT to staker and stake position
// [EXPECTED] staked position ID: 1
//
// [SCENARIO] 3. Skip warmup period
// [INFO] pool tier: 1
// [INFO] skip 2592000 blocks, current height: 125, current time: 1234567900
// [EXPECTED] collected GNS amount: 30629272823998 GNS
// [INFO] skip 1 blocks, current height: 2592125, current time: 1247527900
// [EXPECTED] reward amount per second: 2675512 GNS
//
// [SCENARIO] 4. Check tier 1 reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)
// [SCENARIO] 4.1. Set pool tier to tier 1
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 1 -> 1
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 2675513 -> 2675513
//
// [SCENARIO] 4.2. Collect emission rewards in tier 1 with after 10 blocks
// [INFO] pool tier: 1
// [INFO] skip 10 blocks, current height: 2592126, current time: 1247527905
// [EXPECTED] collected GNS amount: 133775649 GNS
// [INFO] skip 1 blocks, current height: 2592136, current time: 1247527955
// [EXPECTED] reward amount per second: 2675512 GNS
//
// [SCENARIO] 5. Check non-tier reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)
// [SCENARIO] 5.1. Remove pool tier from tier 1
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 1 -> 0
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 2675513 -> 0
//
// [SCENARIO] 5.2. Collect emission rewards in non-tier with after 10 blocks
// [INFO] pool tier: 0
// [INFO] skip 10 blocks, current height: 2592137, current time: 1247527960
// [EXPECTED] collected GNS amount: 0 GNS
// [INFO] skip 1 blocks, current height: 2592147, current time: 1247528010
// [EXPECTED] reward amount per second: 0 GNS
//
// [SCENARIO] 6. Check tier 2 reward (tier 1: 70%, tier 2: 30%, tier 3: 0%)
// [SCENARIO] 6.1. Set pool tier to tier 2
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 0 -> 2
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 0 -> 1605308
//
// [SCENARIO] 6.2. Collect emission rewards in tier 2 with after 10 blocks
// [INFO] pool tier: 2
// [INFO] skip 10 blocks, current height: 2592148, current time: 1247528015
// [EXPECTED] collected GNS amount: 80265399 GNS
// [INFO] skip 1 blocks, current height: 2592158, current time: 1247528065
// [EXPECTED] reward amount per second: 1605307 GNS
//
// [SCENARIO] 6.3. Skip 10 blocks to rewards
// [INFO] skip 10 blocks, current height: 2592159, current time: 1247528070
//
// [SCENARIO] 7. Check non-tier reward (tier 1: 100%, tier 2: 0%, tier 3: 0%)
// [SCENARIO] 7.1. Remove pool tier from tier 2
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 2 -> 0
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 1605308 -> 0
// [INFO] skip 10 blocks, current height: 2592169, current time: 1247528120
//
// [SCENARIO] 8. Check tier 3 reward (tier 1: 80%, tier 2: 0%, tier 3: 20%)
// [SCENARIO] 8.1. Set pool tier to tier 3
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's tier changed: 0 -> 3
// [EXPECTED] gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 pool's emission reward changed: 0 -> 1070205
//
// [SCENARIO] 8.2. Collect emission rewards in tier 3 with after 10 blocks and tier2 10 blocks
// [INFO] pool tier: 3
// [INFO] skip 10 blocks, current height: 2592179, current time: 1247528170
// [EXPECTED] collected GNS amount: 133775648 GNS
// [INFO] skip 1 blocks, current height: 2592189, current time: 1247528220
// [EXPECTED] reward amount per second: 1070204 GNS
