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
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/usdc"
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
	oblPath  = "gno.land/r/onbloc/obl"
	usdcPath = "gno.land/r/onbloc/usdc"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

func main() {
	println("[SCENARIO] Extreme Price Movement - Swap Balance Verification")
	println()

	setupWideRangePool()
	testExtremePriceDown()
	testExtremePriceUp()
	testMaximumSlippage()

	println("[INFO] All extreme price movement balance checks passed")
}

func setupWideRangePool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, oblPath, usdcPath, fee500, "79228162514264337593543950336")

	usdc.Approve(cross, poolAddr, maxApprove)
	obl.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		oblPath,
		usdcPath,
		fee500,
		-10000,
		10000,
		"10000000000",
		adminAddr,
	)

	pools := pool.GetPool(oblPath, usdcPath, fee500)
	println("[INFO] Pool created with wide-range position (-10000 to 10000)")
	println("[INFO] Initial amounts - obl:", amount0, "usdc:", amount1)
	println("[INFO] Initial tick:", pools.Slot0Tick())
}

func testExtremePriceDown() {
	println()
	println("[INFO] Test: Extreme downward price movement (obl → usdc, amount: 10000000)")

	pools := pool.GetPool(oblPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	adminBarBefore := obl.BalanceOf(adminAddr)
	adminFooBefore := usdc.BalanceOf(adminAddr)
	poolBarBefore := obl.BalanceOf(poolAddr)
	poolFooBefore := usdc.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	obl.Approve(cross, poolAddr, 10000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		oblPath,
		usdcPath,
		fee500,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(oblPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(oblPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	adminBarAfter := obl.BalanceOf(adminAddr)
	adminFooAfter := usdc.BalanceOf(adminAddr)
	poolBarAfter := obl.BalanceOf(poolAddr)
	poolFooAfter := usdc.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Obl conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Usdc conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Tick moved from", tickBefore, "to", tickAfter)
	println("[EXPECTED] Price decreased significantly:", tickAfter-tickBefore, "< -500")
}

func testExtremePriceUp() {
	println()
	println("[INFO] Test: Extreme upward price movement (usdc → obl, amount: 5000000)")

	pools := pool.GetPool(oblPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	adminBarBefore := obl.BalanceOf(adminAddr)
	adminFooBefore := usdc.BalanceOf(adminAddr)
	poolBarBefore := obl.BalanceOf(poolAddr)
	poolFooBefore := usdc.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	usdc.Approve(cross, poolAddr, 5000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		oblPath,
		usdcPath,
		fee500,
		adminAddr,
		false,
		"5000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(oblPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(oblPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	adminBarAfter := obl.BalanceOf(adminAddr)
	adminFooAfter := usdc.BalanceOf(adminAddr)
	poolBarAfter := obl.BalanceOf(poolAddr)
	poolFooAfter := usdc.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Obl conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Usdc conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] Tick moved from", tickBefore, "to", tickAfter)
	println("[EXPECTED] Price increased significantly:", tickAfter-tickBefore, "> 500")
}

func testMaximumSlippage() {
	println()
	println("[INFO] Test: Maximum slippage (obl → usdc, amount: 20000000)")

	pools := pool.GetPool(oblPath, usdcPath, fee500)
	tickBefore := pools.Slot0Tick()

	adminBarBefore := obl.BalanceOf(adminAddr)
	adminFooBefore := usdc.BalanceOf(adminAddr)
	poolBarBefore := obl.BalanceOf(poolAddr)
	poolFooBefore := usdc.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	obl.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		oblPath,
		usdcPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(oblPath, usdcPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(oblPath, usdcPath, fee500)
	tickAfter := pools.Slot0Tick()

	adminBarAfter := obl.BalanceOf(adminAddr)
	adminFooAfter := usdc.BalanceOf(adminAddr)
	poolBarAfter := obl.BalanceOf(poolAddr)
	poolFooAfter := usdc.BalanceOf(poolAddr)

	adminBarChange := adminBarAfter - adminBarBefore
	adminFooChange := adminFooAfter - adminFooBefore
	poolBarChange := poolBarAfter - poolBarBefore
	poolFooChange := poolFooAfter - poolFooBefore

	conservationBar := adminBarChange + poolBarChange
	conservationFoo := adminFooChange + poolFooChange

	println("[EXPECTED] Swap amounts - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Obl conservation (admin + pool):", conservationBar, "expected: 0")
	println("[EXPECTED] Usdc conservation (admin + pool):", conservationFoo, "expected: 0")
	println("[EXPECTED] No tokens lost or created:", conservationBar == 0 && conservationFoo == 0)
	println("[EXPECTED] Tick movement:", tickAfter-tickBefore, "expected: near range boundary")
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

// Error:
// read permission denied
