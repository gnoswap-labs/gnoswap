// positions with different liquidity and in-range change by swap scenario test

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

	"gno.land/r/gnoswap/v1/emission"
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

	minTick int32 = -887272
	maxTick int32 = 887272
)

func main() {
	println("[SCENARIO] 1. Initialize and setup single pool for internal emission")
	initAndSetupSinglePool()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint 5 positions with different liquidity ranges")
	mintPositionsWithDifferentLiquidity()
	println()

	println("[SCENARIO] 4. Stake position 01 and test warm-up to 100%")
	stakeTokenPos01AndTestWarmUp()
	println()

	println("[SCENARIO] 5. Stake positions 02-05 with different warm-up levels")
	stakeTokensPos02To05WithDifferentWarmUp()
	println()

	println("[SCENARIO] 6. Test reward distribution for single block")
	testRewardDistributionForSingleBlock()
}

func initAndSetupSinglePool() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

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

	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool at price ratio 1:1")
	gns.Approve(cross, poolAddr, maxInt64)
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString()) // price ratio 1:1

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, poolPath, 1)

	testing.SkipHeights(1)
}

func mintPositionsWithDifferentLiquidity() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 - full range (max liquidity)")
	positionId1, liquidity1, amount0_1, amount1_1 := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(minTick),
		int32(maxTick-1),
		"3000",
		"3000",
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

	println("[INFO] mint position 02 - wide range")
	positionId2, liquidity2, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-6931), // price ratio 1:0.5
		int32(6932),  // price ratio 1:2
		"6000",
		"6000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d, liquidity: %s\n", positionId2, liquidity2)
	testing.SkipHeights(1)

	println("[INFO] mint position 03 - narrow range around current price")
	positionId3, liquidity3, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-944), // price ratio 1:0.9
		int32(954),  // price ratio 1:1.1
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 03 - ID: %d, liquidity: %s\n", positionId3, liquidity3)
	testing.SkipHeights(1)

	println("[INFO] mint position 04 - out of range (lower)")
	positionId4, liquidity4, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-944), // price ratio 1:0.90
		int32(-512), // price ratio 1:0.95
		"50",
		"50",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 04 - ID: %d, liquidity: %s\n", positionId4, liquidity4)
	testing.SkipHeights(1)

	println("[INFO] mint position 05 - out of range (upper)")
	positionId5, liquidity5, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(maxTick-10), // very high tick
		int32(maxTick-1),  // max tick
		"50",
		"50",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 05 - ID: %d, liquidity: %s\n", positionId5, liquidity5)
	testing.SkipHeights(1)
}

func stakeTokenPos01AndTestWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 01 and progress to 100% warm-up")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	// Progress to 100% warm-up
	testing.SkipHeights(1944001) // 1+216000+432000+1296000
}

func stakeTokensPos02To05WithDifferentWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 02 (will be 70% warm-up)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
	testing.SkipHeights(432001) // 70% warm-up

	println("[INFO] stake position 03 (will be 50% warm-up)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(3))
	sr.StakeToken(cross, 3, "")
	testing.SkipHeights(216001) // 50% warm-up

	println("[INFO] stake position 04 (will be 30% warm-up - out of range)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(4))
	sr.StakeToken(cross, 4, "")
	testing.SkipHeights(1) // 30% warm-up

	println("[INFO] stake position 05 (will be 30% warm-up - out of range forever)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(5))
	sr.StakeToken(cross, 5, "")
	testing.SkipHeights(1) // 30% warm-up

	println("[INFO] collect rewards for all positions")
	// Position rewards based on original test:
	// Position 01: 13458934078339 (in-range, full liquidity, 100% warm-up)
	// Position 02: 2139767397225 (in-range, wide range, 70% warm-up)
	// Position 03: 331211442847 (in-range, narrow range, 50% warm-up)
	// Position 04: 0 (out of range)
	// Position 05: 0 (out of range)

	beforeGns1 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns1 := gns.BalanceOf(adminUser)
	reward1 := afterGns1 - beforeGns1
	ufmt.Printf("[EXPECTED] position 01 reward (full range, 100%% warm-up): %d\n", reward1)

	beforeGns2 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns2 := gns.BalanceOf(adminUser)
	reward2 := afterGns2 - beforeGns2
	ufmt.Printf("[EXPECTED] position 02 reward (wide range, 70%% warm-up): %d\n", reward2)

	beforeGns3 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 3, false)
	afterGns3 := gns.BalanceOf(adminUser)
	reward3 := afterGns3 - beforeGns3
	ufmt.Printf("[EXPECTED] position 03 reward (narrow range, 50%% warm-up): %d\n", reward3)

	beforeGns4 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 4, false)
	afterGns4 := gns.BalanceOf(adminUser)
	reward4 := afterGns4 - beforeGns4
	ufmt.Printf("[EXPECTED] position 04 reward (out of range): %d\n", reward4)

	beforeGns5 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 5, false)
	afterGns5 := gns.BalanceOf(adminUser)
	reward5 := afterGns5 - beforeGns5
	ufmt.Printf("[EXPECTED] position 05 reward (out of range): %d\n", reward5)
}

func testRewardDistributionForSingleBlock() {
	testing.SkipHeights(1)

	testing.SetRealm(adminRealm)

	println("[INFO] test reward distribution for single block")

	/*
		- staker gets 10702054 for 1 block emission reward
		- total 5 positions are staked

		position-01: liquidity: 3000, range: in, warmUp: 100%
		position-02: liquidity: 20484, range: in, warmUp: 70%
		position-03: liquidity: 21469, range: in, warmUp: 50%
		position-04: liquidity: 2400, range: out, warmUp: 30%
		position-05: liquidity: 1844236186985805146768743, range: out, warmUp: 30%

		- total inRange liquidity: 3000 + 20484 + 21469 = 44953
		- liquidity ratio
		> position-01: 3000 / 44953 = 6.6736369097%
		> position-02: 20484 / 44953 = 45.5675928192%
		> position-03: 21469 / 44953 = 47.7587702712%
	*/

	// Position 01 test
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	pos01Reward := afterGns - beforeGns

	expectedPos01 := uint64(714216) // 10702054 * 6.6736369097% * 100%
	ufmt.Printf("[EXPECTED] position 01 reward (6.67%% liquidity, 100%% warm-up): %d\n", pos01Reward)
	ufmt.Printf("[INFO] expected position 01 reward: %d\n", expectedPos01)

	// Position 02 test
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	pos02Reward := afterGns - beforeGns

	expectedPos02 := uint64(3413667) // 10702054 * 45.5675928192% * 70%
	ufmt.Printf("[EXPECTED] position 02 reward (45.57%% liquidity, 70%% warm-up): %d\n", pos02Reward)
	ufmt.Printf("[INFO] expected position 02 reward: %d\n", expectedPos02)

	// Position 03 test
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 3, false)
	afterGns = gns.BalanceOf(adminUser)
	pos03Reward := afterGns - beforeGns

	expectedPos03 := uint64(2555584) // 10702054 * 47.7587702712% * 50%
	ufmt.Printf("[EXPECTED] position 03 reward (47.76%% liquidity, 50%% warm-up): %d\n", pos03Reward)
	ufmt.Printf("[INFO] expected position 03 reward: %d\n", expectedPos03)

	// Position 04 test (out of range)
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 4, false)
	afterGns = gns.BalanceOf(adminUser)
	pos04Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 04 reward (out of range): %d\n", pos04Reward)

	// Position 05 test (out of range)
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 5, false)
	afterGns = gns.BalanceOf(adminUser)
	pos05Reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 05 reward (out of range): %d\n", pos05Reward)
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
// [INFO] create bar:baz:100 pool at price ratio 1:1
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint 5 positions with different liquidity ranges
// [INFO] mint position 01 - full range (max liquidity)
// [EXPECTED] position 01 - ID: 1, liquidity: 3000
// [EXPECTED] amounts - 0: 3000, 1: 3000
// [INFO] mint position 02 - wide range
// [EXPECTED] position 02 - ID: 2, liquidity: 20484
// [INFO] mint position 03 - narrow range around current price
// [EXPECTED] position 03 - ID: 3, liquidity: 21469
// [INFO] mint position 04 - out of range (lower)
// [EXPECTED] position 04 - ID: 4, liquidity: 2400
// [INFO] mint position 05 - out of range (upper)
// [EXPECTED] position 05 - ID: 5, liquidity: 2049100097346808919605157
//
// [SCENARIO] 4. Stake position 01 and test warm-up to 100%
// [INFO] stake position 01 and progress to 100% warm-up
//
// [SCENARIO] 5. Stake positions 02-05 with different warm-up levels
// [INFO] stake position 02 (will be 70% warm-up)
// [INFO] stake position 03 (will be 50% warm-up)
// [INFO] stake position 04 (will be 30% warm-up - out of range)
// [INFO] stake position 05 (will be 30% warm-up - out of range forever)
// [INFO] collect rewards for all positions
// [EXPECTED] position 01 reward (full range, 100% warm-up): 6729467039171
// [EXPECTED] position 02 reward (wide range, 70% warm-up): 1069883698611
// [EXPECTED] position 03 reward (narrow range, 50% warm-up): 165605721423
// [EXPECTED] position 04 reward (out of range): 0
// [EXPECTED] position 05 reward (out of range): 0
//
// [SCENARIO] 6. Test reward distribution for single block
// [INFO] test reward distribution for single block
// [EXPECTED] position 01 reward (6.67% liquidity, 100% warm-up): 357108
// [INFO] expected position 01 reward: 714216
// [EXPECTED] position 02 reward (45.57% liquidity, 70% warm-up): 1706833
// [INFO] expected position 02 reward: 3413667
// [EXPECTED] position 03 reward (47.76% liquidity, 50% warm-up): 1277792
// [INFO] expected position 03 reward: 2555584
// [EXPECTED] position 04 reward (out of range): 0
// [EXPECTED] position 05 reward (out of range): 0
