// single position stake, unstake, and restake scenario test

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

	println("[SCENARIO] 3. Mint position 01")
	mintPosition01()
	println()

	println("[SCENARIO] 4. First stake operation")
	firstStakeOperation()
	println()

	println("[SCENARIO] 5. Collect rewards after first stake")
	collectRewardsAfterFirstStake()
	println()

	println("[SCENARIO] 6. Unstake operation")
	unstakeOperation()
	println()

	println("[SCENARIO] 7. Restake operation")
	restakeOperation()
	println()

	println("[SCENARIO] 8. Collect rewards after restake")
	collectRewardsAfterRestake()
	println()

	println("[SCENARIO] 9. Final unstake operation")
	finalUnstakeOperation()
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

	println("[INFO] set pool to tier 1")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	testing.SkipHeights(1)
}

func mintPosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: -100 ~ 100)")
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
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func firstStakeOperation() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for first stake")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))

	println("[INFO] stake position 01 for the first time")
	sr.StakeToken(cross, 1, "")

	ownerAfterStake := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position owner after first stake: %s\n", ownerAfterStake)

	if ownerAfterStake != stakerAddr {
		panic("position should be owned by staker after staking")
	}

	testing.SkipHeights(1)
}

func collectRewardsAfterFirstStake() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(10)

	println("[INFO] collect reward after first stake")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after first stake: %d\n", reward)

	if reward <= 0 {
		panic("should have received reward after first stake")
	}
}

func unstakeOperation() {
	testing.SetRealm(adminRealm)

	println("[INFO] unstake position 01")
	sr.UnStakeToken(cross, 1, false)

	ownerAfterUnstake := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position owner after unstake: %s\n", ownerAfterUnstake)

	if ownerAfterUnstake != adminAddr {
		panic("position should be returned to admin after unstaking")
	}

	println("[INFO] position successfully unstaked and returned to owner")
}

func restakeOperation() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for restake")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))

	println("[INFO] restake position 01")
	sr.StakeToken(cross, 1, "")

	ownerAfterRestake := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position owner after restake: %s\n", ownerAfterRestake)

	if ownerAfterRestake != stakerAddr {
		panic("position should be owned by staker after restaking")
	}

	testing.SkipHeights(1)
	println("[INFO] position successfully restaked")
}

func collectRewardsAfterRestake() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate more rewards")
	testing.SkipHeights(10)

	println("[INFO] collect reward after restake")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after restake: %d\n", reward)

	if reward <= 0 {
		panic("should have received reward after restake")
	}

	println("[INFO] rewards accumulated successfully after restaking")
}

func finalUnstakeOperation() {
	testing.SetRealm(adminRealm)

	println("[INFO] final unstake operation")
	sr.UnStakeToken(cross, 1, false)

	ownerAfterFinalUnstake := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position owner after final unstake: %s\n", ownerAfterFinalUnstake)

	if ownerAfterFinalUnstake != adminAddr {
		panic("position should be returned to admin after final unstaking")
	}

	println("[INFO] stake-unstake-restake cycle completed successfully")
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
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint position 01
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -100 ~ 100)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [EXPECTED] amount0: 1000, amount1: 1000
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 4. First stake operation
// [INFO] approve NFT to staker for first stake
// [INFO] stake position 01 for the first time
// [EXPECTED] position owner after first stake: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 5. Collect rewards after first stake
// [INFO] skip blocks to accumulate rewards
// [INFO] collect reward after first stake
// [EXPECTED] reward after first stake: 17658388
//
// [SCENARIO] 6. Unstake operation
// [INFO] unstake position 01
// [EXPECTED] position owner after unstake: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] position successfully unstaked and returned to owner
//
// [SCENARIO] 7. Restake operation
// [INFO] approve NFT to staker for restake
// [INFO] restake position 01
// [EXPECTED] position owner after restake: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
// [INFO] position successfully restaked
//
// [SCENARIO] 8. Collect rewards after restake
// [INFO] skip blocks to accumulate more rewards
// [INFO] collect reward after restake
// [EXPECTED] reward after restake: 17658388
// [INFO] rewards accumulated successfully after restaking
//
// [SCENARIO] 9. Final unstake operation
// [INFO] final unstake operation
// [EXPECTED] position owner after final unstake: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] stake-unstake-restake cycle completed successfully
