package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"

	"gno.land/r/gnoswap/gns"
)

var (
	user1Addr = testutils.TestAddress("user1")

	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

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

	println("[INFO] Creating atom-atone pool (fee: 3000)")
	pl.CreatePool(cross, atomPath, atonePath, FEE_MEDIUM, "79228162514264337593543950336")

	println("[INFO] Transferring 10000 atom tokens to user1")
	atom.Transfer(cross, user1Addr, 10000)

	println("[EXPECTED] Pool creation completed")
	println()
}

func testPositionMint() {
	println("[SCENARIO] Given: Position minting preparation")
	println("[INFO] Setting position minting permission with admin account")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving atom and atone tokens for pool")
	atom.Approve(cross, poolAddr, 100000000)
	atone.Approve(cross, poolAddr, 100000000)

	println("[INFO] Minting position in atom-atone pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross, atomPath, atonePath, FEE_MEDIUM,
		int32(-887220), int32(887220), "100000000", "100000000",
		"0", "0", max_timeout, adminAddr, "")

	println("[INFO] Minting result - liquidity:", liquidity)
	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 100000000")
	println("[EXPECTED] amount1:", amount1, "expected: 100000000")

	pool, _ := pl.GetPool(atomPath, atonePath, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 100000000")

	poolPath := "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000"
	poolTick := pl.GetSlot0Tick(poolPath)

	println("[INFO] pool tick:", poolTick)
	println()
}

func testExactInputSinglePool() {
	println("[SCENARIO] Given: ExactIn swap preparation")
	poolPath := "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000"

	println("[INFO] Setting swap permission with user1 account")
	user1Realm := testing.NewUserRealm(user1Addr)
	testing.SetRealm(user1Realm)

	println("[INFO] Approving atom and atone tokens")
	atom.Approve(cross, routerAddr, maxApprove)
	atone.Approve(cross, routerAddr, maxApprove)

	println("[INFO] Checking balances before swap")
	poolToken0Before := atom.BalanceOf(poolAddr)
	poolToken1Before := atone.BalanceOf(poolAddr)
	user1Token0Before := atom.BalanceOf(user1Addr)
	user1Token1Before := atone.BalanceOf(user1Addr)

	println("[INFO] Pool atom balance:", poolToken0Before)
	println("[INFO] Pool atone balance:", poolToken1Before)
	println("[INFO] user1 atom balance:", user1Token0Before)
	println("[INFO] user1 atone balance:", user1Token1Before)

	println("[INFO] Executing ExactIn swap (3 atom → atone)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		atomPath,
		atonePath,
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
	poolToken0After := atom.BalanceOf(poolAddr)
	poolToken1After := atone.BalanceOf(poolAddr)
	user1Token0After := atom.BalanceOf(user1Addr)
	user1Token1After := atone.BalanceOf(user1Addr)

	println("[EXPECTED] user1 atom balance change:", user1Token0After, "expected:", user1Token0Before-3)
	println("[EXPECTED] user1 atone balance change:", user1Token1After, "expected:", user1Token1Before+1)
	println("[EXPECTED] pool atom balance change:", poolToken0After, "expected:", poolToken0Before+3)
	println("[EXPECTED] pool atone balance change:", poolToken1After, "expected:", poolToken1Before-1)
	println()
}

// Output:
// [SCENARIO] #1 ExactIn Router Test
// [INFO] Starting scenario: Pool creation → Position minting → ExactIn swap test
//
// [SCENARIO] Given: Pool creation preparation
// [INFO] Setting pool creation permission with admin account
// [INFO] Approving pool creation fee
// [INFO] Creating atom-atone pool (fee: 3000)
// [INFO] Transferring 10000 atom tokens to user1
// [EXPECTED] Pool creation completed
//
// [SCENARIO] Given: Position minting preparation
// [INFO] Setting position minting permission with admin account
// [INFO] Approving atom and atone tokens for pool
// [INFO] Minting position in atom-atone pool
// [INFO] Minting result - liquidity: 100000000
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 100000000 expected: 100000000
// [EXPECTED] amount1: 100000000 expected: 100000000
// [EXPECTED] pool liquidity: 100000000 expected: 100000000
// [INFO] pool tick: 0
//
// [SCENARIO] Given: ExactIn swap preparation
// [INFO] Setting swap permission with user1 account
// [INFO] Approving atom and atone tokens
// [INFO] Checking balances before swap
// [INFO] Pool atom balance: 100000000
// [INFO] Pool atone balance: 100000000
// [INFO] user1 atom balance: 10000
// [INFO] user1 atone balance: 0
// [INFO] Executing ExactIn swap (3 atom → atone)
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [INFO] Checking balances after swap
// [EXPECTED] user1 atom balance change: 9997 expected: 9997
// [EXPECTED] user1 atone balance change: 1 expected: 1
// [EXPECTED] pool atom balance change: 100000003 expected: 100000003
// [EXPECTED] pool atone balance change: 99999999 expected: 99999999
//
// [INFO] Scenario completed
