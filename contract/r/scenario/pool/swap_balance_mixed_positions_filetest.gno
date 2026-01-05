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
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
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
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

func main() {
	println("[SCENARIO] Mixed Positions - Swap Balance Verification")
	println()

	setupPoolWithMixedPositions()
	testExactInputWithMixedPositions()
	testExactOutputWithMixedPositions()

	println("[INFO] All balance checks passed with mixed positions")
}

func setupPoolWithMixedPositions() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, bazPath, quxPath, fee500, "79228162514264337593543950336")

	qux.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	inRangeAmount0, inRangeAmount1 := pool.Mint(
		cross,
		bazPath,
		quxPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	outOfRangeAmount0, outOfRangeAmount1 := pool.Mint(
		cross,
		bazPath,
		quxPath,
		fee500,
		2000,
		4000,
		"500000000",
		adminAddr,
	)

	pools := pool.GetPool(bazPath, quxPath, fee500)
	currentLiquidity := pools.Liquidity().ToString()

	println("[INFO] Pool created with mixed positions")
	println("[INFO] In-range position (-1000 to 1000):", inRangeAmount0, inRangeAmount1)
	println("[INFO] Out-of-range position (2000 to 4000):", outOfRangeAmount0, outOfRangeAmount1)
	println("[INFO] Active liquidity:", currentLiquidity, "expected: 1000000000")
}

func testExactInputWithMixedPositions() {
	testing.SetRealm(adminRealm)

	println()
	println("[INFO] Test: ExactInput swap with mixed positions (baz → qux, amount: 200000)")

	pools := pool.GetPool(bazPath, quxPath, fee500)
	liquidityBefore := pools.Liquidity().ToString()

	adminBarBefore := baz.BalanceOf(adminAddr)
	adminFooBefore := qux.BalanceOf(adminAddr)
	poolBarBefore := baz.BalanceOf(poolAddr)
	poolFooBefore := qux.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	baz.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		bazPath,
		quxPath,
		fee500,
		adminAddr,
		true,
		"200000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(bazPath, quxPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(bazPath, quxPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	adminBarAfter := baz.BalanceOf(adminAddr)
	adminFooAfter := qux.BalanceOf(adminAddr)
	poolBarAfter := baz.BalanceOf(poolAddr)
	poolFooAfter := qux.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Baz conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Qux conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Liquidity before:", liquidityBefore, "after:", liquidityAfter, "expected: unchanged")
	println("[EXPECTED] Tick after:", tickAfter, "expected: < 2000 (out-of-range not activated)")
}

func testExactOutputWithMixedPositions() {
	testing.SetRealm(adminRealm)

	println()
	println("[INFO] Test: ExactOutput swap with mixed positions (qux → baz, amount: -80000)")

	pools := pool.GetPool(bazPath, quxPath, fee500)
	liquidityBefore := pools.Liquidity().ToString()

	adminBarBefore := baz.BalanceOf(adminAddr)
	adminFooBefore := qux.BalanceOf(adminAddr)
	poolBarBefore := baz.BalanceOf(poolAddr)
	poolFooBefore := qux.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	qux.Approve(cross, poolAddr, 300000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		bazPath,
		quxPath,
		fee500,
		adminAddr,
		false,
		"-80000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(bazPath, quxPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(bazPath, quxPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	adminBarAfter := baz.BalanceOf(adminAddr)
	adminFooAfter := qux.BalanceOf(adminAddr)
	poolBarAfter := baz.BalanceOf(poolAddr)
	poolFooAfter := qux.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Baz conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Qux conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Liquidity before:", liquidityBefore, "after:", liquidityAfter, "expected: unchanged")
	println("[EXPECTED] Tick after:", tickAfter, "expected: < 2000 (out-of-range not activated)")
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
// [SCENARIO] Mixed Positions - Swap Balance Verification
//
// [INFO] Pool created with mixed positions
// [INFO] In-range position (-1000 to 1000): 48768198 48768198
// [INFO] Out-of-range position (2000 to 4000): 43051502 0
// [INFO] Active liquidity: 1000000000 expected: 1000000000
//
// [INFO] Test: ExactInput swap with mixed positions (baz → qux, amount: 200000)
// [EXPECTED] Swap amounts - amount0: 200000 amount1: -199860
// [EXPECTED] Baz conservation (admin + pool): 0 expected: 0
// [EXPECTED] Qux conservation (admin + pool): 0 expected: 0
// [EXPECTED] Liquidity before: 1000000000 after: 1000000000 expected: unchanged
// [EXPECTED] Tick after: -4 expected: < 2000 (out-of-range not activated)
//
// [INFO] Test: ExactOutput swap with mixed positions (qux → baz, amount: -80000)
// [EXPECTED] Swap amounts - amount0: -80000 amount1: 80016
// [EXPECTED] Baz conservation (admin + pool): 0 expected: 0
// [EXPECTED] Qux conservation (admin + pool): 0 expected: 0
// [EXPECTED] Liquidity before: 1000000000 after: 1000000000 expected: unchanged
// [EXPECTED] Tick after: -3 expected: < 2000 (out-of-range not activated)
// [INFO] All balance checks passed with mixed positions
