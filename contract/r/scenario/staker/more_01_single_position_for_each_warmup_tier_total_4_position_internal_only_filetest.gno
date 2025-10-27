// single position for each warm-up tier (total 4 positions) - internal only scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
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

	poolAddr, _          = access.GetAddress(prabc.ROLE_POOL.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup single pool for internal emission")
	initAndSetupSinglePool()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint 4 positions")
	mintPositions()
	println()

	println("[SCENARIO] 4. Stake position 01 and test warm-up progression")
	stakeTokenPos01AndTestWarmUp()
	println()

	println("[SCENARIO] 5. Stake positions 02-04")
	stakeTokensPos02To04()
	println()

	println("[SCENARIO] 6. Collect rewards for all positions")
	collectRewardsAll()
	println()

	println("[SCENARIO] 7. Test single block reward distribution")
	testSingleBlockRewardDistribution()
}

func initAndSetupSinglePool() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] set community pool distribution to 0%")
	emission.ChangeDistributionPct(
		cross,
		1, 7500, // staker
		2, 2500, // devOps
		3, 0, // community pool
		4, 0, // xGNS
	)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, poolPath, 1)

	testing.SkipHeights(1)
}

func mintPositions() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 (tick range: -30 ~ 30)")
	positionId1, liquidity1, amount0_1, amount1_1 := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 - ID: %d, liquidity: %s\n", positionId1, liquidity1)
	ufmt.Printf("[EXPECTED] amounts - 0: %s, 1: %s\n", amount0_1, amount1_1)
	testing.SkipHeights(1)

	println("[INFO] mint position 02 (tick range: -30 ~ 30)")
	positionId2, liquidity2, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d, liquidity: %s\n", positionId2, liquidity2)
	testing.SkipHeights(1)

	println("[INFO] mint position 03 (tick range: -30 ~ 30)")
	positionId3, liquidity3, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 03 - ID: %d, liquidity: %s\n", positionId3, liquidity3)
	testing.SkipHeights(1)

	println("[INFO] mint position 04 (tick range: -30 ~ 30)")
	positionId4, liquidity4, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 04 - ID: %d, liquidity: %s\n", positionId4, liquidity4)
	testing.SkipHeights(1)
}

func stakeTokenPos01AndTestWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
	testing.SkipHeights(1)

	println("[INFO] collect reward for 30% warm-up")
	userOldGns := gns.BalanceOf(adminUser)
	communityOldGns := gns.BalanceOf(communityPoolAddr)

	sr.CollectReward(cross, 1, false)

	userNewGns := gns.BalanceOf(adminUser)
	communityNewGns := gns.BalanceOf(communityPoolAddr)

	userReward := userNewGns - userOldGns
	communityReward := communityNewGns - communityOldGns

	ufmt.Printf("[EXPECTED] user reward (30%% warm-up): %d\n", userReward)
	ufmt.Printf("[EXPECTED] community pool reward (unclaimable + penalty): %d\n", communityReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 50% warm-up")
	testing.SkipHeights(216001)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldGns = gns.BalanceOf(adminUser)
	communityOldGns = gns.BalanceOf(communityPoolAddr)

	sr.CollectReward(cross, 1, false)

	userNewGns = gns.BalanceOf(adminUser)
	communityNewGns = gns.BalanceOf(communityPoolAddr)

	userReward = userNewGns - userOldGns
	communityReward = communityNewGns - communityOldGns

	ufmt.Printf("[EXPECTED] user reward (50%% warm-up): %d\n", userReward)
	ufmt.Printf("[EXPECTED] community pool reward (50%% penalty): %d\n", communityReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 70% warm-up")
	testing.SkipHeights(432001)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldGns = gns.BalanceOf(adminUser)
	communityOldGns = gns.BalanceOf(communityPoolAddr)

	sr.CollectReward(cross, 1, false)

	userNewGns = gns.BalanceOf(adminUser)
	communityNewGns = gns.BalanceOf(communityPoolAddr)

	userReward = userNewGns - userOldGns
	communityReward = communityNewGns - communityOldGns

	ufmt.Printf("[EXPECTED] user reward (70%% warm-up): %d\n", userReward)
	ufmt.Printf("[EXPECTED] community pool reward (30%% penalty): %d\n", communityReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 100% warm-up")
	testing.SkipHeights(1728000)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldGns = gns.BalanceOf(adminUser)
	communityOldGns = gns.BalanceOf(communityPoolAddr)

	sr.CollectReward(cross, 1, false)

	userNewGns = gns.BalanceOf(adminUser)
	communityNewGns = gns.BalanceOf(communityPoolAddr)

	userReward = userNewGns - userOldGns
	communityReward = communityNewGns - communityOldGns

	ufmt.Printf("[EXPECTED] user reward (100%% warm-up): %d\n", userReward)
	ufmt.Printf("[EXPECTED] community pool reward (no penalty): %d\n", communityReward)

	testing.SkipHeights(1)
}

func stakeTokensPos02To04() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	println("[INFO] stake position 03")
	gnft.Approve(cross, stakerAddr, positionIdFrom(3))
	sr.StakeToken(cross, 3, "")
	testing.SkipHeights(1)

	println("[INFO] stake position 04")
	gnft.Approve(cross, stakerAddr, positionIdFrom(4))
	sr.StakeToken(cross, 4, "")
	testing.SkipHeights(1)
}

func collectRewardsAll() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect rewards for all positions")
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)
	sr.CollectReward(cross, 3, false)
	sr.CollectReward(cross, 4, false)
}

func testSingleBlockRewardDistribution() {
	testing.SkipHeights(1)

	testing.SetRealm(adminRealm)

	println("[INFO] test reward distribution for single block")

	// Position 01 (100% warm-up)
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	pos01Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward (100%% warm-up, 25%% share): %d\n", pos01Reward)

	// Position 02 (30% warm-up)
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	pos02Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 02 reward (30%% warm-up, 25%% share): %d\n", pos02Reward)

	// Position 03 (30% warm-up)
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 3, false)
	afterGns = gns.BalanceOf(adminUser)
	pos03Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 03 reward (30%% warm-up, 25%% share): %d\n", pos03Reward)

	// Position 04 (30% warm-up)
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 4, false)
	afterGns = gns.BalanceOf(adminUser)
	pos04Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 04 reward (30%% warm-up, 25%% share): %d\n", pos04Reward)

	// Verify distribution: each position gets 25% of emission reward
	// 1 block emission reward for staker = 10702054
	// Each position receives 10702054 * 25% = 2675513.5
	totalEmissionPerBlock := uint64(10702054)
	expectedPerPosition := totalEmissionPerBlock / 4

	ufmt.Printf("[INFO] expected reward per position (25%% share): %d\n", expectedPerPosition)
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
// [SCENARIO] 1. Initialize and setup single pool for internal emission
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] set community pool distribution to 0%
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint 4 positions
// [INFO] mint position 01 (tick range: -30 ~ 30)
// [EXPECTED] position 01 - ID: 1, liquidity: 33360
// [EXPECTED] amounts - 0: 50, 1: 50
// [INFO] mint position 02 (tick range: -30 ~ 30)
// [EXPECTED] position 02 - ID: 2, liquidity: 33360
// [INFO] mint position 03 (tick range: -30 ~ 30)
// [EXPECTED] position 03 - ID: 3, liquidity: 33360
// [INFO] mint position 04 (tick range: -30 ~ 30)
// [EXPECTED] position 04 - ID: 4, liquidity: 33360
//
// [SCENARIO] 4. Stake position 01 and test warm-up progression
// [INFO] stake position 01
// [INFO] collect reward for 30% warm-up
// [EXPECTED] user reward (30% warm-up): 4013269
// [EXPECTED] community pool reward (unclaimable + penalty): 73576607
// [INFO] progress to 50% warm-up
// [EXPECTED] user reward (50% warm-up): 6688782
// [EXPECTED] community pool reward (50% penalty): 6688782
// [INFO] progress to 70% warm-up
// [EXPECTED] user reward (70% warm-up): 9364294
// [EXPECTED] community pool reward (30% penalty): 4013270
// [INFO] progress to 100% warm-up
// [EXPECTED] user reward (100% warm-up): 13377564
// [EXPECTED] community pool reward (no penalty): 0
//
// [SCENARIO] 5. Stake positions 02-04
// [INFO] stake position 02
// [INFO] stake position 03
// [INFO] stake position 04
//
// [SCENARIO] 6. Collect rewards for all positions
// [INFO] collect rewards for all positions
//
// [SCENARIO] 7. Test single block reward distribution
// [INFO] test reward distribution for single block
// [EXPECTED] position 01 reward (100% warm-up, 25% share): 3344391
// [EXPECTED] position 02 reward (30% warm-up, 25% share): 1003317
// [EXPECTED] position 03 reward (30% warm-up, 25% share): 1003317
// [EXPECTED] position 04 reward (30% warm-up, 25% share): 1003317
// [INFO] expected reward per position (25% share): 2675513
