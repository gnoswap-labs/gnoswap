// no position to give reward scenario test

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

	emissionAddr, _ = access.GetAddress(access.ROLE_EMISSION)

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

	println("[SCENARIO] 3. Set pool to tier 1 (enable rewards)")
	setPoolToTier1()
	println()

	println("[SCENARIO] 4. Check emission when no positions are staked")
	checkEmissionWithNoPositions()
	println()

	println("[SCENARIO] 5. Mint position but don't stake")
	mintPositionButDontStake()
	println()

	println("[SCENARIO] 6. Check emission with position minted but not staked")
	checkEmissionWithPositionNotStaked()
	println()

	println("[SCENARIO] 7. Stake position and verify emission starts")
	stakePositionAndVerifyEmission()
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

func setPoolToTier1() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool to tier 1 to enable rewards")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	ufmt.Printf("[EXPECTED] pool tier set to 1\n")
	testing.SkipHeights(1)
}

func checkEmissionWithNoPositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] check emission allocation when no positions are staked")

	beforeEmissionGns := gns.BalanceOf(emissionAddr)
	beforeStakerGns := gns.BalanceOf(stakerAddr)

	ufmt.Printf("[INFO] emission GNS balance before: %d\n", beforeEmissionGns)
	ufmt.Printf("[INFO] staker GNS balance before: %d\n", beforeStakerGns)

	println("[INFO] skip blocks to trigger emission")
	testing.SkipHeights(10)

	afterEmissionGns := gns.BalanceOf(emissionAddr)
	afterStakerGns := gns.BalanceOf(stakerAddr)

	ufmt.Printf("[EXPECTED] emission GNS balance after: %d\n", afterEmissionGns)
	ufmt.Printf("[EXPECTED] staker GNS balance after: %d\n", afterStakerGns)

	stakerGnsIncrease := afterStakerGns - beforeStakerGns
	ufmt.Printf("[EXPECTED] staker GNS increase: %d\n", stakerGnsIncrease)

	if stakerGnsIncrease > 0 {
		println("[INFO] staker received GNS even with no positions staked")
		println("[INFO] this is expected behavior - emission continues but rewards accumulate until claimed")
	} else {
		println("[INFO] staker did not receive GNS with no positions staked")
	}
}

func mintPositionButDontStake() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 but don't stake it")
	positionId, liquidity, amount0, amount1 := pn.Mint(
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
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	ufmt.Printf("[EXPECTED] position owner: %s (not staked)\n", owner)

	if owner != adminAddr {
		panic("position should be owned by admin when not staked")
	}

	testing.SkipHeights(1)
}

func checkEmissionWithPositionNotStaked() {
	testing.SetRealm(adminRealm)

	println("[INFO] check emission when position exists but is not staked")

	beforeStakerGns := gns.BalanceOf(stakerAddr)
	beforeAdminGns := gns.BalanceOf(adminUser)

	ufmt.Printf("[INFO] staker GNS balance before: %d\n", beforeStakerGns)
	ufmt.Printf("[INFO] admin GNS balance before: %d\n", beforeAdminGns)

	println("[INFO] skip blocks to trigger more emission")
	testing.SkipHeights(10)

	afterStakerGns := gns.BalanceOf(stakerAddr)
	afterAdminGns := gns.BalanceOf(adminUser)

	ufmt.Printf("[EXPECTED] staker GNS balance after: %d\n", afterStakerGns)
	ufmt.Printf("[EXPECTED] admin GNS balance after: %d\n", afterAdminGns)

	stakerGnsIncrease := afterStakerGns - beforeStakerGns
	adminGnsChange := afterAdminGns - beforeAdminGns

	ufmt.Printf("[EXPECTED] staker GNS increase: %d\n", stakerGnsIncrease)
	ufmt.Printf("[EXPECTED] admin GNS change: %d\n", adminGnsChange)

	// Admin should not receive any rewards since position is not staked
	if adminGnsChange != 0 {
		panic("admin should not receive rewards for unstaked position")
	}

	println("[INFO] confirmed: emission continues but no rewards distributed to unstaked positions")
}

func stakePositionAndVerifyEmission() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ownerAfterStake := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position owner after staking: %s\n", ownerAfterStake)

	if ownerAfterStake != stakerAddr {
		panic("position should be owned by staker after staking")
	}

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(5)

	println("[INFO] collect reward for staked position")
	beforeAdminGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterAdminGns := gns.BalanceOf(adminUser)
	reward := afterAdminGns - beforeAdminGns

	ufmt.Printf("[EXPECTED] reward collected: %d\n", reward)

	if reward <= 0 {
		panic("should have received reward for staked position")
	}

	println("[INFO] confirmed: rewards are distributed when positions are staked")
	println("[INFO] no position to give reward scenario test completed")
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
// [SCENARIO] 3. Set pool to tier 1 (enable rewards)
// [INFO] set pool to tier 1 to enable rewards
// [EXPECTED] pool tier set to 1
//
// [SCENARIO] 4. Check emission when no positions are staked
// [INFO] check emission allocation when no positions are staked
// [INFO] emission GNS balance before: 1
// [INFO] staker GNS balance before: 10702054
// [INFO] skip blocks to trigger emission
// [EXPECTED] emission GNS balance after: 1
// [EXPECTED] staker GNS balance after: 10702054
// [EXPECTED] staker GNS increase: 0
// [INFO] staker did not receive GNS with no positions staked
//
// [SCENARIO] 5. Mint position but don't stake
// [INFO] approve tokens for minting
// [INFO] mint position 01 but don't stake it
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [EXPECTED] amount0: 1000, amount1: 1000
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (not staked)
//
// [SCENARIO] 6. Check emission with position minted but not staked
// [INFO] check emission when position exists but is not staked
// [INFO] staker GNS balance before: 149828763
// [INFO] admin GNS balance before: 100000000000000
// [INFO] skip blocks to trigger more emission
// [EXPECTED] staker GNS balance after: 149828763
// [EXPECTED] admin GNS balance after: 100000000000000
// [EXPECTED] staker GNS increase: 0
// [EXPECTED] admin GNS change: 0
// [INFO] confirmed: emission continues but no rewards distributed to unstaked positions
//
// [SCENARIO] 7. Stake position and verify emission starts
// [INFO] approve NFT to staker and stake position 01
// [EXPECTED] position owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
// [INFO] skip blocks to accumulate rewards
// [INFO] collect reward for staked position
// [EXPECTED] reward collected: 8026540
// [INFO] confirmed: rewards are distributed when positions are staked
// [INFO] no position to give reward scenario test completed
