// mint and stake position

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"
	fee        = uint32(3000)
)

func main() {
	println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	println("[SCENARIO] 2. Mint and Stake Position")
	mintAndStakePosition()
	println()

	println("[SCENARIO] 3. Skip blocks and check position")
	testing.SkipHeights(10)
	println("[INFO] Current block height:", std.ChainHeight())
	println()

	println("[SCENARIO] 4. UnStake Position")
	unstakePosition()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	defaultTokenAmount := int64(100000000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	foo.Approve(cross, stakerAddr, consts.INT64_MAX)

	ufmt.Printf("[INFO] Creating %s:%s:%d pool (tick: %d)\n", token0Path, token1Path, fee, 0)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// Setup internal incentive pool
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	testing.SetRealm(adminRealm)
	staker.SetPoolTierByAdmin(cross, poolPath, 1)
}

func mintAndStakePosition() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Mint and Stake Position")
	positionId, liquidity, _, _, _ := staker.MintAndStake(
		cross,
		token0Path,
		token1Path,
		fee,
		-6960,
		6960,
		"10000000",
		"10000000",
		"1",
		"1",
		9999999999,
		"",
	)

	stakeHeight := staker.GetDepositStakeHeight(positionId)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Staked height should be %d\n", stakeHeight)
}

func unstakePosition() {
	testing.SetRealm(aliceRealm)

	positionId := uint64(1)

	ufmt.Println("[INFO] Unstake Position")
	_, unstakedAmount0, unstakedAmount1 := staker.UnStakeToken(cross, positionId, false)

	ufmt.Printf("[EXPECTED] Unstaked Amount0 should be %s\n", unstakedAmount0)
	ufmt.Printf("[EXPECTED] Unstaked Amount1 should be %s\n", unstakedAmount1)
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Creating gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000 pool (tick: 0)
//
// [SCENARIO] 2. Mint and Stake Position
// [INFO] Mint and Stake Position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 34026470
// [EXPECTED] Staked height should be 123
//
// [SCENARIO] 3. Skip blocks and check position
// [INFO] Current block height: 133
//
// [SCENARIO] 4. UnStake Position
// [INFO] Unstake Position
// [EXPECTED] Unstaked Amount0 should be 9999999
// [EXPECTED] Unstaked Amount1 should be 9999999
