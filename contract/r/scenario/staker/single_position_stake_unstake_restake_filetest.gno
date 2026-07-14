// single position stake, unstake, and restake scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/access"

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

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Mint position 01")
	mintPosition01(cur)
	println()

	println("[SCENARIO] 4. First stake operation")
	firstStakeOperation(cur)
	println()

	println("[SCENARIO] 5. Collect rewards after first stake")
	collectRewardsAfterFirstStake(cur)
	println()

	println("[SCENARIO] 6. Unstake operation")
	unstakeOperation(cur)
	println()

	println("[SCENARIO] 7. Restake operation")
	restakeOperation(cur)
	println()

	println("[SCENARIO] 8. Collect rewards after restake")
	collectRewardsAfterRestake(cur)
	println()

	println("[SCENARIO] 9. Final unstake operation")
	finalUnstakeOperation(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross(cur), 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross(cur), 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross(cur), barPath, bazPath, 100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SkipHeights(1)
}

func mintPosition01(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: -100 ~ 100)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
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
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(cur, positionId))
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func firstStakeOperation(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for first stake")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))

	println("[INFO] stake position 01 for the first time")
	sr.StakeToken(cross(cur), 1, "")

	ownerAfterStake := gnft.MustOwnerOf(positionIdFrom(cur, 1))
	ufmt.Printf("[EXPECTED] position owner after first stake: %s\n", ownerAfterStake)

	if ownerAfterStake != stakerAddr {
		panic("position should be owned by staker after staking")
	}

	testing.SkipHeights(1)
}

func collectRewardsAfterFirstStake(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(10)

	println("[INFO] collect reward after first stake")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterGns := gns.BalanceOf(adminUser)
	reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after first stake: %d\n", reward)

	if reward <= 0 {
		panic("should have received reward after first stake")
	}
}

func unstakeOperation(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] unstake position 01")
	sr.UnStakeToken(cross(cur), 1)

	ownerAfterUnstake := gnft.MustOwnerOf(positionIdFrom(cur, 1))
	ufmt.Printf("[EXPECTED] position owner after unstake: %s\n", ownerAfterUnstake)

	if ownerAfterUnstake != adminAddr {
		panic("position should be returned to admin after unstaking")
	}

	println("[INFO] position successfully unstaked and returned to owner")
}

func restakeOperation(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for restake")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))

	println("[INFO] restake position 01")
	sr.StakeToken(cross(cur), 1, "")

	ownerAfterRestake := gnft.MustOwnerOf(positionIdFrom(cur, 1))
	ufmt.Printf("[EXPECTED] position owner after restake: %s\n", ownerAfterRestake)

	if ownerAfterRestake != stakerAddr {
		panic("position should be owned by staker after restaking")
	}

	testing.SkipHeights(1)
	println("[INFO] position successfully restaked")
}

func collectRewardsAfterRestake(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate more rewards")
	testing.SkipHeights(10)

	println("[INFO] collect reward after restake")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterGns := gns.BalanceOf(adminUser)
	reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after restake: %d\n", reward)

	if reward <= 0 {
		panic("should have received reward after restake")
	}

	println("[INFO] rewards accumulated successfully after restaking")
}

func finalUnstakeOperation(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] final unstake operation")
	sr.UnStakeToken(cross(cur), 1)

	ownerAfterFinalUnstake := gnft.MustOwnerOf(positionIdFrom(cur, 1))
	ufmt.Printf("[EXPECTED] position owner after final unstake: %s\n", ownerAfterFinalUnstake)

	if ownerAfterFinalUnstake != adminAddr {
		panic("position should be returned to admin after final unstaking")
	}

	println("[INFO] stake-unstake-restake cycle completed successfully")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
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
// [EXPECTED] position owner: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 4. First stake operation
// [INFO] approve NFT to staker for first stake
// [INFO] stake position 01 for the first time
// [EXPECTED] position owner after first stake: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
//
// [SCENARIO] 5. Collect rewards after first stake
// [INFO] skip blocks to accumulate rewards
// [INFO] collect reward after first stake
// [EXPECTED] reward after first stake: 44145964
//
// [SCENARIO] 6. Unstake operation
// [INFO] unstake position 01
// [EXPECTED] position owner after unstake: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] position successfully unstaked and returned to owner
//
// [SCENARIO] 7. Restake operation
// [INFO] approve NFT to staker for restake
// [INFO] restake position 01
// [EXPECTED] position owner after restake: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [INFO] position successfully restaked
//
// [SCENARIO] 8. Collect rewards after restake
// [INFO] skip blocks to accumulate more rewards
// [INFO] collect reward after restake
// [EXPECTED] reward after restake: 44145964
// [INFO] rewards accumulated successfully after restaking
//
// [SCENARIO] 9. Final unstake operation
// [INFO] final unstake operation
// [EXPECTED] position owner after final unstake: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [INFO] stake-unstake-restake cycle completed successfully
