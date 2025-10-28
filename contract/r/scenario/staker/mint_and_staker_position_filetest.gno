// mint and stake position

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"
	fee        = uint32(3000)

	maxInt64 int64 = 9223372036854775807
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
	println("[INFO] Current block height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 4. UnStake Position")
	unstakePosition()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)

	defaultTokenAmount := int64(100000000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	bar.Approve(cross, stakerAddr, maxInt64)
	foo.Approve(cross, stakerAddr, maxInt64)

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
	staker.SetPoolTier(cross, poolPath, 1)
}

func mintAndStakePosition() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Mint and Stake Position")
	positionId, liquidity, amount0, amount1, _ := staker.MintAndStake(
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

	stakeTimestamp := staker.GetDepositStakeTimestamp(positionId)

	poolBalance0 := common.BalanceOf(token0Path, poolAddr)
	poolBalance1 := common.BalanceOf(token1Path, poolAddr)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Staked timestamp should be %d\n", stakeTimestamp)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Pool Balance0 should be %d\n", poolBalance0)
	ufmt.Printf("[EXPECTED] Pool Balance1 should be %d\n", poolBalance1)
}

func unstakePosition() {
	testing.SetRealm(aliceRealm)

	positionId := uint64(1)

	ufmt.Println("[INFO] Unstake Position")
	staker.UnStakeToken(cross, positionId, false)
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
// [EXPECTED] Staked timestamp should be 1234567890
// [EXPECTED] Amount0 should be 10000000
// [EXPECTED] Amount1 should be 10000000
// [EXPECTED] Pool Balance0 should be 10000000
// [EXPECTED] Pool Balance1 should be 10000000
//
// [SCENARIO] 3. Skip blocks and check position
// [INFO] Current block height: 133
//
// [SCENARIO] 4. UnStake Position
// [INFO] Unstake Position
