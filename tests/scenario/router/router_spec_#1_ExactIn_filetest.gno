package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	user1Addr = testutils.TestAddress("user1")

	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	max_timeout int64 = 9999999999

	maxApprove int64 = 9223372036854775806
)

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] #1 ExactIn Router Test")
	println("[INFO] Starting scenario: Pool creation → Position minting → ExactIn swap test")
	println()

	testcreatePool()
	testPositionMint()
	testExactInputSinglePool()
	
	println("[INFO] Scenario completed")
}

func testcreatePool() {
	println("[SCENARIO] Given: Pool creation preparation")
	println("[INFO] Setting pool creation permission with admin account")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	
	println("[INFO] Creating bar-baz pool (fee: 3000)")
	pl.CreatePool(cross, barPath, bazPath, FEE_MEDIUM, "79228162514264337593543950336")

	println("[INFO] Transferring 10000 bar tokens to user1")
	bar.Transfer(cross, user1Addr, 10000)
	
	println("[EXPECTED] Pool creation completed")
	println()
}

func testPositionMint() {
	println("[SCENARIO] Given: Position minting preparation")
	println("[INFO] Setting position minting permission with admin account")
	testing.SetRealm(adminRealm)
	
	println("[INFO] Approving bar and baz tokens for pool")
	bar.Approve(cross, poolAddr, 100000000)
	baz.Approve(cross, poolAddr, 100000000)

	println("[INFO] Minting position in bar-baz pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross, barPath, bazPath, FEE_MEDIUM,
		int32(-887220), int32(887220), "100000000", "100000000",
		"0", "0", max_timeout, adminAddr, adminAddr, "",
	)

	println("[INFO] Minting result - liquidity:", liquidity)
	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 100000000")
	println("[EXPECTED] amount1:", amount1, "expected: 100000000")

	pool := pl.GetPool(barPath, bazPath, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 100000000")

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
	poolTick := pl.PoolGetSlot0Tick(poolPath)

	println("[INFO] pool tick:", poolTick)
	println()
}

func testExactInputSinglePool() {
	println("[SCENARIO] Given: ExactIn swap preparation")
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"

	println("[INFO] Setting swap permission with user1 account")
	user1Realm := std.NewUserRealm(user1Addr)
	testing.SetRealm(user1Realm)

	println("[INFO] Approving bar and baz tokens")
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, routerAddr, maxApprove)

	println("[INFO] Checking balances before swap")
	poolToken0Before := bar.BalanceOf(poolAddr)
	poolToken1Before := baz.BalanceOf(poolAddr)
	user1Token0Before := bar.BalanceOf(user1Addr)
	user1Token1Before := baz.BalanceOf(user1Addr)
	
	println("[INFO] Pool bar balance:", poolToken0Before)
	println("[INFO] Pool baz balance:", poolToken1Before)
	println("[INFO] user1 bar balance:", user1Token0Before)
	println("[INFO] user1 baz balance:", user1Token1Before)

	println("[INFO] Executing ExactIn swap (3 bar → baz)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		bazPath,
		"3",
		poolPath,
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 3")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[INFO] Checking balances after swap")
	poolToken0After := bar.BalanceOf(poolAddr)
	poolToken1After := baz.BalanceOf(poolAddr)
	user1Token0After := bar.BalanceOf(user1Addr)
	user1Token1After := baz.BalanceOf(user1Addr)

	println("[EXPECTED] user1 bar balance change:", user1Token0After, "expected:", user1Token0Before-3)
	println("[EXPECTED] user1 baz balance change:", user1Token1After, "expected:", user1Token1Before+1)
	println("[EXPECTED] pool bar balance change:", poolToken0After, "expected:", poolToken0Before+3)
	println("[EXPECTED] pool baz balance change:", poolToken1After, "expected:", poolToken1Before-1)
	println()
}

// Output:
// [SCENARIO] #1 ExactIn Router Test
// [INFO] Starting scenario: Pool creation → Position minting → ExactIn swap test
//
// [SCENARIO] Given: Pool creation preparation
// [INFO] Setting pool creation permission with admin account
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 3000)
// [INFO] Transferring 10000 bar tokens to user1
// [EXPECTED] Pool creation completed
//
// [SCENARIO] Given: Position minting preparation
// [INFO] Setting position minting permission with admin account
// [INFO] Approving bar and baz tokens for pool
// [INFO] Minting position in bar-baz pool
// [INFO] Minting result - liquidity: 100000000
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 100000000 expected: 100000000
// [EXPECTED] amount1: 100000000 expected: 100000000
// [EXPECTED] pool liquidity: 100000000 expected: 100000000
// [INFO] pool tick: 0
//
// [SCENARIO] Given: ExactIn swap preparation
// [INFO] Setting swap permission with user1 account
// [INFO] Approving bar and baz tokens
// [INFO] Checking balances before swap
// [INFO] Pool bar balance: 100000000
// [INFO] Pool baz balance: 100000000
// [INFO] user1 bar balance: 10000
// [INFO] user1 baz balance: 0
// [INFO] Executing ExactIn swap (3 bar → baz)
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [INFO] Checking balances after swap
// [EXPECTED] user1 bar balance change: 9997 expected: 9997
// [EXPECTED] user1 baz balance change: 1 expected: 1
// [EXPECTED] pool bar balance change: 100000003 expected: 100000003
// [EXPECTED] pool baz balance change: 99999999 expected: 99999999
//
// [INFO] Scenario completed
