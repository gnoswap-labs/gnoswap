// single position for each warm-up tier (total 4 positions) - two external incentives scenario test

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

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_365DAYS int64 = 365 * 24 * 60 * 60

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint 4 positions")
	mintPositions()
	println()

	println("[SCENARIO] 4. Create external incentives (bar and baz)")
	createExternalIncentives()
	println()

	println("[SCENARIO] 5. Stake position 01 and test warm-up to 100%")
	stakeTokenPos01ToWarmUp100()
	println()

	println("[SCENARIO] 6. Stake positions 02-04 with different warm-up levels")
	stakeTokensPos02To04WithDifferentWarmUp()
	println()

	println("[SCENARIO] 7. Test single block reward distribution")
	testSingleBlockRewardDistribution()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

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
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

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

func createExternalIncentives() {
	testing.SetRealm(adminRealm)

	println("[INFO] create external incentive for bar token (365 days)")
	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		barPath,
		365_000_000_000, // 365 billion bar tokens
		1234569600,
		1234569600+TIMESTAMP_365DAYS,
	)

	ufmt.Printf("[INFO] bar external incentive created - reward per block: ~23148\n")

	println("[INFO] create external incentive for baz token (365 days)")
	baz.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		bazPath,
		3_650_000_000, // 3650 million baz tokens
		1234569600,
		1234569600+TIMESTAMP_365DAYS,
	)

	ufmt.Printf("[INFO] baz external incentive created - reward per block: ~23\n")

	// Make external incentives start
	leftHeight := 978 - std.ChainHeight()
	if leftHeight > 0 {
		testing.SkipHeights(leftHeight + 5) // skip 5 blocks more
	}
}

func stakeTokenPos01ToWarmUp100() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
	testing.SkipHeights(1)

	println("[INFO] collect reward for 30% warm-up")
	userOldBar := bar.BalanceOf(adminUser)
	userOldBaz := baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	userNewBar := bar.BalanceOf(adminUser)
	userNewBaz := baz.BalanceOf(adminUser)

	barReward := userNewBar - userOldBar
	bazReward := userNewBaz - userOldBaz

	ufmt.Printf("[EXPECTED] bar reward (30%% warm-up): %d\n", barReward)
	ufmt.Printf("[EXPECTED] baz reward (30%% warm-up): %d\n", bazReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 50% warm-up")
	testing.SkipHeights(216001)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldBar = bar.BalanceOf(adminUser)
	userOldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	userNewBar = bar.BalanceOf(adminUser)
	userNewBaz = baz.BalanceOf(adminUser)

	barReward = userNewBar - userOldBar
	bazReward = userNewBaz - userOldBaz

	ufmt.Printf("[EXPECTED] bar reward (50%% warm-up): %d\n", barReward)
	ufmt.Printf("[EXPECTED] baz reward (50%% warm-up): %d\n", bazReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 70% warm-up")
	testing.SkipHeights(432000)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldBar = bar.BalanceOf(adminUser)
	userOldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	userNewBar = bar.BalanceOf(adminUser)
	userNewBaz = baz.BalanceOf(adminUser)

	barReward = userNewBar - userOldBar
	bazReward = userNewBaz - userOldBaz

	ufmt.Printf("[EXPECTED] bar reward (70%% warm-up): %d\n", barReward)
	ufmt.Printf("[EXPECTED] baz reward (70%% warm-up): %d\n", bazReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 100% warm-up")
	testing.SkipHeights(1296000)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)
	userOldBar = bar.BalanceOf(adminUser)
	userOldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	userNewBar = bar.BalanceOf(adminUser)
	userNewBaz = baz.BalanceOf(adminUser)

	barReward = userNewBar - userOldBar
	bazReward = userNewBaz - userOldBaz

	ufmt.Printf("[EXPECTED] bar reward (100%% warm-up): %d\n", barReward)
	ufmt.Printf("[EXPECTED] baz reward (100%% warm-up): %d\n", bazReward)

	testing.SkipHeights(1)
}

func stakeTokensPos02To04WithDifferentWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 02 (will be 70% warm-up)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
	testing.SkipHeights(432001) // 70% warm-up

	println("[INFO] stake position 03 (will be 50% warm-up)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(3))
	sr.StakeToken(cross, 3, "")
	testing.SkipHeights(216001) // 50% warm-up

	println("[INFO] stake position 04 (will be 30% warm-up)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(4))
	sr.StakeToken(cross, 4, "")
	testing.SkipHeights(1) // 30% warm-up

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
	// 1 block skipped
	// bar reward of 1 block: 23148 will be distributed to all positions
	// baz reward of 1 block: 23 will be distributed to all positions
	// since all positions have same amount of liquidity, it will be distributed equally
	// 23148 / 4 = 5787
	// 23 / 4 = 5.75

	// Position 01 (100% warm-up)
	oldBar := bar.BalanceOf(adminUser)
	oldBaz := baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	newBar := bar.BalanceOf(adminUser)
	newBaz := baz.BalanceOf(adminUser)

	pos01BarReward := newBar - oldBar
	pos01BazReward := newBaz - oldBaz

	ufmt.Printf("[EXPECTED] position 01 bar reward (100%% warm-up): %d\n", pos01BarReward)
	ufmt.Printf("[EXPECTED] position 01 baz reward (100%% warm-up): %d\n", pos01BazReward)

	// Position 02 (70% warm-up)
	oldBar = bar.BalanceOf(adminUser)
	oldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 2, false)

	newBar = bar.BalanceOf(adminUser)
	newBaz = baz.BalanceOf(adminUser)

	pos02BarReward := newBar - oldBar
	pos02BazReward := newBaz - oldBaz

	ufmt.Printf("[EXPECTED] position 02 bar reward (70%% warm-up): %d\n", pos02BarReward)
	ufmt.Printf("[EXPECTED] position 02 baz reward (70%% warm-up): %d\n", pos02BazReward)

	// Position 03 (50% warm-up)
	oldBar = bar.BalanceOf(adminUser)
	oldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 3, false)

	newBar = bar.BalanceOf(adminUser)
	newBaz = baz.BalanceOf(adminUser)

	pos03BarReward := newBar - oldBar
	pos03BazReward := newBaz - oldBaz

	ufmt.Printf("[EXPECTED] position 03 bar reward (50%% warm-up): %d\n", pos03BarReward)
	ufmt.Printf("[EXPECTED] position 03 baz reward (50%% warm-up): %d\n", pos03BazReward)

	// Position 04 (30% warm-up)
	oldBar = bar.BalanceOf(adminUser)
	oldBaz = baz.BalanceOf(adminUser)

	sr.CollectReward(cross, 4, false)

	newBar = bar.BalanceOf(adminUser)
	newBaz = baz.BalanceOf(adminUser)

	pos04BarReward := newBar - oldBar
	pos04BazReward := newBaz - oldBaz

	ufmt.Printf("[EXPECTED] position 04 bar reward (30%% warm-up): %d\n", pos04BarReward)
	ufmt.Printf("[EXPECTED] position 04 baz reward (30%% warm-up): %d\n", pos04BazReward)
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
// [INFO] set community pool distribution to 0%
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
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
// [SCENARIO] 4. Create external incentives (bar and baz)
// [INFO] create external incentive for bar token (365 days)
// [INFO] bar external incentive created - reward per block: ~23148
// [INFO] create external incentive for baz token (365 days)
// [INFO] baz external incentive created - reward per block: ~23
//
// [SCENARIO] 5. Stake position 01 and test warm-up to 100%
// [INFO] stake position 01
// [INFO] collect reward for 30% warm-up
// [EXPECTED] bar reward (30% warm-up): 6944
// [EXPECTED] baz reward (30% warm-up): 69
// [INFO] progress to 50% warm-up
// [EXPECTED] bar reward (50% warm-up): 11574
// [EXPECTED] baz reward (50% warm-up): 115
// [INFO] progress to 70% warm-up
// [EXPECTED] bar reward (70% warm-up): 16203
// [EXPECTED] baz reward (70% warm-up): 161
// [INFO] progress to 100% warm-up
// [EXPECTED] bar reward (100% warm-up): 23148
// [EXPECTED] baz reward (100% warm-up): 231
//
// [SCENARIO] 6. Stake positions 02-04 with different warm-up levels
// [INFO] stake position 02 (will be 70% warm-up)
// [INFO] stake position 03 (will be 50% warm-up)
// [INFO] stake position 04 (will be 30% warm-up)
// [INFO] collect rewards for all positions
//
// [SCENARIO] 7. Test single block reward distribution
// [INFO] test reward distribution for single block
// [EXPECTED] position 01 bar reward (100% warm-up): 5787
// [EXPECTED] position 01 baz reward (100% warm-up): 57
// [EXPECTED] position 02 bar reward (70% warm-up): 4050
// [EXPECTED] position 02 baz reward (70% warm-up): 39
// [EXPECTED] position 03 bar reward (50% warm-up): 2893
// [EXPECTED] position 03 baz reward (50% warm-up): 28
// [EXPECTED] position 04 bar reward (30% warm-up): 1736
// [EXPECTED] position 04 baz reward (30% warm-up): 17
