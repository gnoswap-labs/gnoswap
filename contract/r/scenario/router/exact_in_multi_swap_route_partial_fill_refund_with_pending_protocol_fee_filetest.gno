// exact in multi swap route where the second hop partially fills while the
// protocol fee realm is halted: the intermediate-token leftover is refunded to
// the swapper, but the swap fee kept as a pending protocol fee stays in the
// router and is excluded from the refund

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	t *testing.T

	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	maxInt64 int64 = 9223372036854775807

	swapFeeBps int64 = 100 // 1%
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize Setup with 1% swap fee")
	initializeSetup(cur)
	println()

	println("[SCENARIO] 2. Create Deep Pool And Mint Position (bar:baz:500)")
	createPool(cur, barPath, bazPath, 500, 0)
	mintPosition(cur, barPath, bazPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 3. Create Thin Pool And Mint Narrow Position (baz:qux:500)")
	createPool(cur, bazPath, quxPath, 500, 0)
	mintPosition(cur, bazPath, quxPath, 500, -10, 10, "100000", "100000")
	println()

	println("[SCENARIO] 4. Halt Protocol Fee Only")
	haltProtocolFee(cur)
	println()

	println("[SCENARIO] 5. ExactInSwapRoute bar -> baz -> qux with partial fill and pending protocol fee")
	exactInSwapRouteWithPendingFeeCheck(cur,
		barPath,
		quxPath,
		"10000000",
		"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500",
		"100",
		"1",
	)
	println()
}

func initializeSetup(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	router.SetSwapFee(cross(cur), uint64(swapFeeBps))

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	bar.Approve(cross(cur), routerAddr, maxInt64)

	println("[INFO] swap fee (bps):", router.GetSwapFee())
}

func createPool(cur realm, token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross(cur),
		token0Path,
		token1Path,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(cur realm, token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
		token0Path,
		token1Path,
		fee,
		minTick,
		maxTick,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func haltProtocolFee(cur realm) {
	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross(cur), halt.OpTypeProtocolFee, true)

	ufmt.Printf("[EXPECTED] IsHaltedProtocolFee: %t\n", halt.IsHaltedProtocolFee())
	ufmt.Printf("[EXPECTED] IsHaltedRouter: %t\n", halt.IsHaltedRouter())
}

func exactInSwapRouteWithPendingFeeCheck(cur realm,
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	minAmountOut string,
) {
	testing.SetRealm(adminRealm)

	beforeSwapperBar := bar.BalanceOf(adminAddr)
	beforeSwapperBaz := baz.BalanceOf(adminAddr)
	beforeSwapperQux := qux.BalanceOf(adminAddr)

	beforeRouterBar := bar.BalanceOf(routerAddr)
	beforeRouterBaz := baz.BalanceOf(routerAddr)
	beforeRouterQux := qux.BalanceOf(routerAddr)

	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(
		cross(cur),
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		queryRatios,
		minAmountOut,
		int64(9999999999),
		"",
	)

	swapperBarDelta := bar.BalanceOf(adminAddr) - beforeSwapperBar
	swapperBazDelta := baz.BalanceOf(adminAddr) - beforeSwapperBaz
	swapperQuxDelta := qux.BalanceOf(adminAddr) - beforeSwapperQux
	routerQuxDelta := qux.BalanceOf(routerAddr) - beforeRouterQux

	pendingQuxFee := router.GetPendingProtocolFees()[quxPath]
	grossOutput := swapperQuxDelta + pendingQuxFee

	ufmt.Printf("[EXPECTED] inputTokenAmount(BAR): %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount(QUX): %s\n", outputTokenAmount)
	ufmt.Printf("[EXPECTED] swapper BAR balance changed: %d\n", swapperBarDelta)
	ufmt.Printf("[EXPECTED] swapper BAZ balance changed (refunded leftover): %d\n", swapperBazDelta)
	ufmt.Printf("[EXPECTED] swapper QUX balance changed: %d\n", swapperQuxDelta)
	ufmt.Printf("[EXPECTED] pending protocol fee (QUX): %d\n", pendingQuxFee)
	ufmt.Printf("[EXPECTED] router QUX balance changed: %d\n", routerQuxDelta)
	ufmt.Printf("[EXPECTED] gross output before swap fee: %d\n", grossOutput)

	// the full input was consumed and the swap produced output
	uassert.Equal(t, ufmt.Sprintf("%d", -swapperBarDelta), inputTokenAmount)
	uassert.Equal(t, ufmt.Sprintf("%d", swapperQuxDelta), outputTokenAmount)

	// the second hop only partially filled, so part of the intermediate baz
	// came back to the swapper as a refund
	uassert.True(t, swapperBazDelta > 0)

	// the swap fee could not be forwarded to the halted protocol fee realm:
	// it stays in the router, matches the recorded pending amount exactly,
	// and is excluded from the refund
	uassert.True(t, pendingQuxFee > 0)
	uassert.Equal(t, routerQuxDelta, pendingQuxFee)
	uassert.Equal(t, pendingQuxFee, grossOutput*swapFeeBps/10000)

	// no other route token is left behind in the router
	uassert.Equal(t, bar.BalanceOf(routerAddr), beforeRouterBar)
	uassert.Equal(t, baz.BalanceOf(routerAddr), beforeRouterBaz)
}

// Output:
// [SCENARIO] 1. Initialize Setup with 1% swap fee
// [INFO] swap fee (bps): 100
//
// [SCENARIO] 2. Create Deep Pool And Mint Position (bar:baz:500)
// [EXPECTED] created gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:500 pool at tick 0
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 3. Create Thin Pool And Mint Narrow Position (baz:qux:500)
// [EXPECTED] created gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500 pool at tick 0
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 200060003
// [EXPECTED] amount0: 100000
// [EXPECTED] amount1: 100000
//
// [SCENARIO] 4. Halt Protocol Fee Only
// [EXPECTED] IsHaltedProtocolFee: true
// [EXPECTED] IsHaltedRouter: false
//
// [SCENARIO] 5. ExactInSwapRoute bar -> baz -> qux with partial fill and pending protocol fee
// [EXPECTED] inputTokenAmount(BAR): 10000000
// [EXPECTED] outputTokenAmount(QUX): 99000
// [EXPECTED] swapper BAR balance changed: -10000000
// [EXPECTED] swapper BAZ balance changed (refunded leftover): 9609680
// [EXPECTED] swapper QUX balance changed: 99000
// [EXPECTED] pending protocol fee (QUX): 999
// [EXPECTED] router QUX balance changed: 999
// [EXPECTED] gross output before swap fee: 99999
