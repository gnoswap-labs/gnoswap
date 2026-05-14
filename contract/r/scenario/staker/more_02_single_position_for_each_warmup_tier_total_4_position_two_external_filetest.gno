// single position for each warm-up tier (total 4 positions) - two external incentives scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"

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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_365DAYS int64 = 365 * 24 * 60 * 60

	poolPath = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create atom:atone:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint 4 positions")
	mintPositions()
	println()

	println("[SCENARIO] 4. Create external incentives (atom and atone)")
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
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] set community pool distribution to 0%")
	emission.ChangeDistributionPct(
		cross,
		7500, // liquidityStakerPct
		2500, // devOpsPct
		0, // communityPoolPct
		0, // govStakerPct
	)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create atom:atone:100 pool")
	pl.CreatePool(cross, atomPath, atonePath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func mintPositions() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, poolAddr, maxInt64)
	atone.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 (tick range: -30 ~ 30)")
	positionId1, liquidity1, amount0_1, amount1_1 := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 - ID: %d, liquidity: %s\n", positionId1, liquidity1)
	ufmt.Printf("[EXPECTED] amounts - 0: %s, 1: %s\n", amount0_1, amount1_1)
	testing.SkipHeights(1)

	println("[INFO] mint position 02 (tick range: -30 ~ 30)")
	positionId2, liquidity2, _, _ := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d, liquidity: %s\n", positionId2, liquidity2)
	testing.SkipHeights(1)

	println("[INFO] mint position 03 (tick range: -30 ~ 30)")
	positionId3, liquidity3, _, _ := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 03 - ID: %d, liquidity: %s\n", positionId3, liquidity3)
	testing.SkipHeights(1)

	println("[INFO] mint position 04 (tick range: -30 ~ 30)")
	positionId4, liquidity4, _, _ := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 04 - ID: %d, liquidity: %s\n", positionId4, liquidity4)
	testing.SkipHeights(1)
}

func createExternalIncentives() {
	testing.SetRealm(adminRealm)

	println("[INFO] create external incentive for atom token (365 days)")
	atom.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		365_000_000_000, // 365 billion atom tokens
		1234569600,
		1234569600+TIMESTAMP_365DAYS,
	)

	ufmt.Printf("[INFO] atom external incentive created - reward per block: ~23148\n")

	println("[INFO] create external incentive for atone token (365 days)")
	atone.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atonePath,
		3_650_000_000, // 3650 million atone tokens
		1234569600,
		1234569600+TIMESTAMP_365DAYS,
	)

	ufmt.Printf("[INFO] atone external incentive created - reward per block: ~23\n")

	// Make external incentives start
	leftHeight := 978 - runtime.ChainHeight()
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
	userOldAtom := atom.BalanceOf(adminUser)
	userOldAtone := atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	userNewAtom := atom.BalanceOf(adminUser)
	userNewAtone := atone.BalanceOf(adminUser)

	atomReward := userNewAtom - userOldAtom
	atoneReward := userNewAtone - userOldAtone

	ufmt.Printf("[EXPECTED] atom reward (30%% warm-up): %d\n", atomReward)
	ufmt.Printf("[EXPECTED] atone reward (30%% warm-up): %d\n", atoneReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 50% warm-up")
	testing.SkipHeights(216001)
	sr.CollectReward(cross, 1)

	testing.SkipHeights(1)
	userOldAtom = atom.BalanceOf(adminUser)
	userOldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	userNewAtom = atom.BalanceOf(adminUser)
	userNewAtone = atone.BalanceOf(adminUser)

	atomReward = userNewAtom - userOldAtom
	atoneReward = userNewAtone - userOldAtone

	ufmt.Printf("[EXPECTED] atom reward (50%% warm-up): %d\n", atomReward)
	ufmt.Printf("[EXPECTED] atone reward (50%% warm-up): %d\n", atoneReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 70% warm-up")
	testing.SkipHeights(432000)
	sr.CollectReward(cross, 1)

	testing.SkipHeights(1)
	userOldAtom = atom.BalanceOf(adminUser)
	userOldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	userNewAtom = atom.BalanceOf(adminUser)
	userNewAtone = atone.BalanceOf(adminUser)

	atomReward = userNewAtom - userOldAtom
	atoneReward = userNewAtone - userOldAtone

	ufmt.Printf("[EXPECTED] atom reward (70%% warm-up): %d\n", atomReward)
	ufmt.Printf("[EXPECTED] atone reward (70%% warm-up): %d\n", atoneReward)

	testing.SkipHeights(1)

	println("[INFO] progress to 100% warm-up")
	testing.SkipHeights(1296000)
	sr.CollectReward(cross, 1)

	testing.SkipHeights(1)
	userOldAtom = atom.BalanceOf(adminUser)
	userOldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	userNewAtom = atom.BalanceOf(adminUser)
	userNewAtone = atone.BalanceOf(adminUser)

	atomReward = userNewAtom - userOldAtom
	atoneReward = userNewAtone - userOldAtone

	ufmt.Printf("[EXPECTED] atom reward (100%% warm-up): %d\n", atomReward)
	ufmt.Printf("[EXPECTED] atone reward (100%% warm-up): %d\n", atoneReward)

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
	sr.CollectReward(cross, 1)
	sr.CollectReward(cross, 2)
	sr.CollectReward(cross, 3)
	sr.CollectReward(cross, 4)
}

func testSingleBlockRewardDistribution() {
	testing.SkipHeights(1)

	testing.SetRealm(adminRealm)

	println("[INFO] test reward distribution for single block")
	// 1 block skipped
	// atom reward of 1 block: 23148 will be distributed to all positions
	// atone reward of 1 block: 23 will be distributed to all positions
	// since all positions have same amount of liquidity, it will be distributed equally
	// 23148 / 4 = 5787
	// 23 / 4 = 5.75

	// Position 01 (100% warm-up)
	oldAtom := atom.BalanceOf(adminUser)
	oldAtone := atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	newAtom := atom.BalanceOf(adminUser)
	newAtone := atone.BalanceOf(adminUser)

	pos01AtomReward := newAtom - oldAtom
	pos01AtoneReward := newAtone - oldAtone

	ufmt.Printf("[EXPECTED] position 01 atom reward (100%% warm-up): %d\n", pos01AtomReward)
	ufmt.Printf("[EXPECTED] position 01 atone reward (100%% warm-up): %d\n", pos01AtoneReward)

	// Position 02 (70% warm-up)
	oldAtom = atom.BalanceOf(adminUser)
	oldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 2)

	newAtom = atom.BalanceOf(adminUser)
	newAtone = atone.BalanceOf(adminUser)

	pos02AtomReward := newAtom - oldAtom
	pos02AtoneReward := newAtone - oldAtone

	ufmt.Printf("[EXPECTED] position 02 atom reward (70%% warm-up): %d\n", pos02AtomReward)
	ufmt.Printf("[EXPECTED] position 02 atone reward (70%% warm-up): %d\n", pos02AtoneReward)

	// Position 03 (50% warm-up)
	oldAtom = atom.BalanceOf(adminUser)
	oldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 3)

	newAtom = atom.BalanceOf(adminUser)
	newAtone = atone.BalanceOf(adminUser)

	pos03AtomReward := newAtom - oldAtom
	pos03AtoneReward := newAtone - oldAtone

	ufmt.Printf("[EXPECTED] position 03 atom reward (50%% warm-up): %d\n", pos03AtomReward)
	ufmt.Printf("[EXPECTED] position 03 atone reward (50%% warm-up): %d\n", pos03AtoneReward)

	// Position 04 (30% warm-up)
	oldAtom = atom.BalanceOf(adminUser)
	oldAtone = atone.BalanceOf(adminUser)

	sr.CollectReward(cross, 4)

	newAtom = atom.BalanceOf(adminUser)
	newAtone = atone.BalanceOf(adminUser)

	pos04AtomReward := newAtom - oldAtom
	pos04AtoneReward := newAtone - oldAtone

	ufmt.Printf("[EXPECTED] position 04 atom reward (30%% warm-up): %d\n", pos04AtomReward)
	ufmt.Printf("[EXPECTED] position 04 atone reward (30%% warm-up): %d\n", pos04AtoneReward)
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
// [SCENARIO] 2. Create atom:atone:100 pool
// [INFO] create atom:atone:100 pool
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
// [SCENARIO] 4. Create external incentives (atom and atone)
// [INFO] create external incentive for atom token (365 days)
// [INFO] atom external incentive created - reward per block: ~23148
// [INFO] create external incentive for atone token (365 days)
// [INFO] atone external incentive created - reward per block: ~23
//
// [SCENARIO] 5. Stake position 01 and test warm-up to 100%
// [INFO] stake position 01
// [INFO] collect reward for 30% warm-up
// [EXPECTED] atom reward (30% warm-up): 17360
// [EXPECTED] atone reward (30% warm-up): 172
// [INFO] progress to 50% warm-up
// [EXPECTED] atom reward (50% warm-up): 28935
// [EXPECTED] atone reward (50% warm-up): 287
// [INFO] progress to 70% warm-up
// [EXPECTED] atom reward (70% warm-up): 40509
// [EXPECTED] atone reward (70% warm-up): 402
// [INFO] progress to 100% warm-up
// [EXPECTED] atom reward (100% warm-up): 57869
// [EXPECTED] atone reward (100% warm-up): 574
//
// [SCENARIO] 6. Stake positions 02-04 with different warm-up levels
// [INFO] stake position 02 (will be 70% warm-up)
// [INFO] stake position 03 (will be 50% warm-up)
// [INFO] stake position 04 (will be 30% warm-up)
// [INFO] collect rewards for all positions
//
// [SCENARIO] 7. Test single block reward distribution
// [INFO] test reward distribution for single block
// [EXPECTED] position 01 atom reward (100% warm-up): 14467
// [EXPECTED] position 01 atone reward (100% warm-up): 143
// [EXPECTED] position 02 atom reward (70% warm-up): 10126
// [EXPECTED] position 02 atone reward (70% warm-up): 100
// [EXPECTED] position 03 atom reward (50% warm-up): 7233
// [EXPECTED] position 03 atone reward (50% warm-up): 71
// [EXPECTED] position 04 atom reward (30% warm-up): 4340
// [EXPECTED] position 04 atone reward (30% warm-up): 42
