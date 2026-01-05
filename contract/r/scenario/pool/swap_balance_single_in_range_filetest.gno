// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	maxApprove      int64  = 9223372036854775806
	poolCreationFee int64  = 100_000_000
	fee500          uint32 = 500
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

func main() {
	println("[SCENARIO] Single In-Range Position - Swap Balance Verification")
	println()

	setupPool()
	testExactInputSwap()
	testExactOutputSwap()

	println("[INFO] All balance checks passed")
}

func setupPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, "79228162514264337593543950336")

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	println("[INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)")
	println("[INFO] Initial amounts - bar:", amount0, "foo:", amount1)
}

func testExactInputSwap() {
	testing.SetRealm(adminRealm)

	println()
	println("[INFO] Test: ExactInput swap (bar → foo, amount: 100000)")

	pools := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := pools.Slot0Tick()

	adminBarBefore := bar.BalanceOf(adminAddr)
	adminFooBefore := foo.BalanceOf(adminAddr)
	poolBarBefore := bar.BalanceOf(poolAddr)
	poolFooBefore := foo.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 100000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"100000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := pools.Slot0Tick()

	adminBarAfter := bar.BalanceOf(adminAddr)
	adminFooAfter := foo.BalanceOf(adminAddr)
	poolBarAfter := bar.BalanceOf(poolAddr)
	poolFooAfter := foo.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Admin bar balance changed by:", adminBarChange, "expected: -100000")
	println("[EXPECTED] Pool bar balance changed by:", poolBarChange, "expected: 100000")
	println("[EXPECTED] Bar conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Foo conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Tick moved from", tickBefore, "to", tickAfter, "expected: price decreased")
}

func testExactOutputSwap() {
	testing.SetRealm(adminRealm)

	println()
	println("[INFO] Test: ExactOutput swap (foo → bar, amount: -50000)")

	pools := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := pools.Slot0Tick()

	adminBarBefore := bar.BalanceOf(adminAddr)
	adminFooBefore := foo.BalanceOf(adminAddr)
	poolBarBefore := bar.BalanceOf(poolAddr)
	poolFooBefore := foo.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"-50000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := pools.Slot0Tick()

	adminBarAfter := bar.BalanceOf(adminAddr)
	adminFooAfter := foo.BalanceOf(adminAddr)
	poolBarAfter := bar.BalanceOf(poolAddr)
	poolFooAfter := foo.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Admin bar balance changed by:", adminBarChange, "expected: 50000")
	println("[EXPECTED] Pool bar balance changed by:", poolBarChange, "expected: -50000")
	println("[EXPECTED] Bar conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Foo conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Tick moved from", tickBefore, "to", tickAfter, "expected: price increased")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Single In-Range Position - Swap Balance Verification
//
// [INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)
// [INFO] Initial amounts - bar: 48768198 foo: 48768198
//
// [INFO] Test: ExactInput swap (bar → foo, amount: 100000)
// [EXPECTED] Swap amounts - amount0: 100000 amount1: -99940
// [EXPECTED] Admin bar balance changed by: -100000 expected: -100000
// [EXPECTED] Pool bar balance changed by: 100000 expected: 100000
// [EXPECTED] Bar conservation (admin + pool): 0 expected: 0
// [EXPECTED] Foo conservation (admin + pool): 0 expected: 0
// [EXPECTED] Tick moved from 0 to -2 expected: price decreased
//
// [INFO] Test: ExactOutput swap (foo → bar, amount: -50000)
// [EXPECTED] Swap amounts - amount0: -50000 amount1: 50019
// [EXPECTED] Admin bar balance changed by: 50000 expected: 50000
// [EXPECTED] Pool bar balance changed by: -50000 expected: -50000
// [EXPECTED] Bar conservation (admin + pool): 0 expected: 0
// [EXPECTED] Foo conservation (admin + pool): 0 expected: 0
// [EXPECTED] Tick moved from -2 to -1 expected: price increased
// [INFO] All balance checks passed
