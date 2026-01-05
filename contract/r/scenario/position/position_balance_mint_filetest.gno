// position mint balance check

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

	ufmt.Println("[SCENARIO] 2. Mint position and check balances")
	testMintAndBalance()
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

func testMintAndBalance() {
	testing.SetRealm(adminRealm)

	barBalanceBefore := bar.BalanceOf(adminAddr)
	fooBalanceBefore := foo.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] User BAR balance before mint should be %d\n", barBalanceBefore)
	ufmt.Printf("[EXPECTED] User FOO balance before mint should be %d\n", fooBalanceBefore)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position (8000~12000)")
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
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 deposited should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 deposited should be %s\n", amount1)

	barBalanceAfter := bar.BalanceOf(adminAddr)
	fooBalanceAfter := foo.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] User BAR balance after mint should be %d\n", barBalanceAfter)
	ufmt.Printf("[EXPECTED] User FOO balance after mint should be %d\n", fooBalanceAfter)

	barChange := barBalanceBefore - barBalanceAfter
	fooChange := fooBalanceBefore - fooBalanceAfter

	ufmt.Printf("[EXPECTED] BAR balance decreased by %d\n", barChange)
	ufmt.Printf("[EXPECTED] FOO balance decreased by %d\n", fooChange)

	pos, _ := position.GetPosition(positionId)
	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
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
// [SCENARIO] 2. Mint position and check balances
// [EXPECTED] User BAR balance before mint should be 100000000000000
// [EXPECTED] User FOO balance before mint should be 100000000000000
// [INFO] Minting position (8000~12000)
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 318704392
// [EXPECTED] Amount0 deposited should be 18394892
// [EXPECTED] Amount1 deposited should be 50000000
// [EXPECTED] User BAR balance after mint should be 99999981605108
// [EXPECTED] User FOO balance after mint should be 99999950000000
// [EXPECTED] BAR balance decreased by 18394892
// [EXPECTED] FOO balance decreased by 50000000
// [EXPECTED] Position liquidity should be 318704392
// [EXPECTED] Position token0 balance should be 18394892
// [EXPECTED] Position token1 balance should be 50000000
// [EXPECTED] Pool token0 balance should be 18394892
// [EXPECTED] Pool token1 balance should be 50000000
// [EXPECTED] Pool liquidity should be 318704392
