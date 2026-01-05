// position increase liquidity balance check

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64  = 9223372036854775807
	fee500    uint32 = 500
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintInitialPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Increase liquidity and check balances")
	testIncreaseLiquidityAndBalance()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintInitialPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting initial position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Initial liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Initial amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Initial amount1 should be %s\n", amount1)
}

func testIncreaseLiquidityAndBalance() {
	testing.SetRealm(adminRealm)

	barBalanceBefore := bar.BalanceOf(adminAddr)
	fooBalanceBefore := foo.BalanceOf(adminAddr)
	pos, _ := position.GetPosition(1)
	liquidityBefore := pos.Liquidity().ToString()

	ufmt.Printf("[EXPECTED] User BAR balance before increase should be %d\n", barBalanceBefore)
	ufmt.Printf("[EXPECTED] User FOO balance before increase should be %d\n", fooBalanceBefore)
	ufmt.Printf("[EXPECTED] Position liquidity before increase should be %s\n", liquidityBefore)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Increasing liquidity")
	_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
		cross,
		1,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] Added liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 added should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 added should be %s\n", amount1)

	barBalanceAfter := bar.BalanceOf(adminAddr)
	fooBalanceAfter := foo.BalanceOf(adminAddr)
	pos, _ = position.GetPosition(1)
	liquidityAfter := pos.Liquidity().ToString()

	ufmt.Printf("[EXPECTED] User BAR balance after increase should be %d\n", barBalanceAfter)
	ufmt.Printf("[EXPECTED] User FOO balance after increase should be %d\n", fooBalanceAfter)
	ufmt.Printf("[EXPECTED] Position liquidity after increase should be %s\n", liquidityAfter)

	barChange := barBalanceBefore - barBalanceAfter
	fooChange := fooBalanceBefore - fooBalanceAfter

	ufmt.Printf("[EXPECTED] BAR balance decreased by %d\n", barChange)
	ufmt.Printf("[EXPECTED] FOO balance decreased by %d\n", fooChange)

	ufmt.Printf("[EXPECTED] Position token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position token1 balance should be %s\n", pos.Token1Balance().ToString())

	poolInfo := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Pool token0 balance should be %s\n", poolInfo.BalanceToken0().ToString())
	ufmt.Printf("[EXPECTED] Pool token1 balance should be %s\n", poolInfo.BalanceToken1().ToString())
	ufmt.Printf("[EXPECTED] Pool liquidity should be %s\n", poolInfo.Liquidity().ToString())
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting initial position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Initial liquidity should be 318704392
// [EXPECTED] Initial amount0 should be 18394892
// [EXPECTED] Initial amount1 should be 50000000
//
// [SCENARIO] 3. Increase liquidity and check balances
// [EXPECTED] User BAR balance before increase should be 99999981605108
// [EXPECTED] User FOO balance before increase should be 99999950000000
// [EXPECTED] Position liquidity before increase should be 318704392
// [INFO] Increasing liquidity
// [EXPECTED] Added liquidity should be 318704392
// [EXPECTED] Amount0 added should be 18394892
// [EXPECTED] Amount1 added should be 50000000
// [EXPECTED] User BAR balance after increase should be 99999963210216
// [EXPECTED] User FOO balance after increase should be 99999900000000
// [EXPECTED] Position liquidity after increase should be 637408784
// [EXPECTED] BAR balance decreased by 18394892
// [EXPECTED] FOO balance decreased by 50000000
// [EXPECTED] Position token0 balance should be 36789783
// [EXPECTED] Position token1 balance should be 99999999
// [EXPECTED] Pool token0 balance should be 36789784
// [EXPECTED] Pool token1 balance should be 100000000
// [EXPECTED] Pool liquidity should be 637408784
