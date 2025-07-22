// single position stake and unstake in same block scenario test

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
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

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

	println("[SCENARIO] 4. Stake and unstake in same block")
	stakeAndUnstakeInSameBlock()
	println()

	println("[SCENARIO] 5. Verify final state")
	verifyFinalState()
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
	ufmt.Printf("[EXPECTED] initial position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func stakeAndUnstakeInSameBlock() {
	testing.SetRealm(adminRealm)

	println("[INFO] check initial state before staking")
	initialOwner := gnft.MustOwnerOf(positionIdFrom(1))
	initialGnsBalance := gns.BalanceOf(adminUser)

	ufmt.Printf("[INFO] initial owner: %s\n", initialOwner)
	ufmt.Printf("[INFO] initial GNS balance: %d\n", initialGnsBalance)

	println("[INFO] approve NFT to staker")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))

	println("[INFO] stake position 01")
	sr.StakeToken(cross, 1, "")

	ownerAfterStake := gnft.MustOwnerOf(positionIdFrom(1))

	ufmt.Printf("[EXPECTED] owner after stake: %s\n", ownerAfterStake)

	if ownerAfterStake != stakerAddr {
		panic("position should be owned by staker after staking")
	}

	println("[INFO] immediately unstake position 01 (same block)")
	sr.UnStakeToken(cross, 1, false)

	ownerAfterUnstake := gnft.MustOwnerOf(positionIdFrom(1))
	gnsAfterUnstake := gns.BalanceOf(adminUser)

	ufmt.Printf("[EXPECTED] owner after unstake: %s\n", ownerAfterUnstake)
	ufmt.Printf("[EXPECTED] GNS balance after unstake: %d\n", gnsAfterUnstake)

	if ownerAfterUnstake != adminAddr {
		panic("position should be returned to admin after unstaking")
	}

	// Check if any reward was accumulated in same block
	rewardFromSameBlock := gnsAfterUnstake - initialGnsBalance
	ufmt.Printf("[EXPECTED] reward from same block staking/unstaking: %d\n", rewardFromSameBlock)

	if rewardFromSameBlock != 0 {
		ufmt.Printf("[INFO] same block staking/unstaking yielded reward: %d\n", rewardFromSameBlock)
	} else {
		println("[INFO] no reward accumulated from same block staking/unstaking")
	}

	println("[INFO] same block stake and unstake completed successfully")
}

func verifyFinalState() {
	testing.SetRealm(adminRealm)

	println("[INFO] verify final state after same block operations")

	finalOwner := gnft.MustOwnerOf(positionIdFrom(1))

	ufmt.Printf("[EXPECTED] final position owner: %s\n", finalOwner)

	if finalOwner != adminAddr {
		panic("final owner should be admin")
	}

	println("[INFO] position is back to original owner and staker state is clean")

	// Test that position can still be staked normally after same-block operations
	println("[INFO] test normal staking after same-block operations")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	testing.SkipHeights(1)

	verifyOwner := gnft.MustOwnerOf(positionIdFrom(1))

	ufmt.Printf("[EXPECTED] verification - owner after normal stake: %s\n", verifyOwner)

	if verifyOwner != stakerAddr {
		panic("position should be staked normally after same-block operations")
	}

	println("[INFO] same-block operations do not affect normal staking functionality")
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
// [EXPECTED] initial position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 4. Stake and unstake in same block
// [INFO] check initial state before staking
// [INFO] initial owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] initial GNS balance: 100000000000000
// [INFO] approve NFT to staker
// [INFO] stake position 01
// [EXPECTED] owner after stake: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
// [INFO] immediately unstake position 01 (same block)
// [EXPECTED] owner after unstake: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [EXPECTED] GNS balance after unstake: 100000000000000
// [EXPECTED] reward from same block staking/unstaking: 0
// [INFO] no reward accumulated from same block staking/unstaking
// [INFO] same block stake and unstake completed successfully
//
// [SCENARIO] 5. Verify final state
// [INFO] verify final state after same block operations
// [EXPECTED] final position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] position is back to original owner and staker state is clean
// [INFO] test normal staking after same-block operations
// [EXPECTED] verification - owner after normal stake: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
// [INFO] same-block operations do not affect normal staking functionality
