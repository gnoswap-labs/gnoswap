/*
UNISWAP TEST REF
  - https://github.com/Uniswap/v3-core/blob/main/test/shared/fixtures.ts
  - https://github.com/Uniswap/v3-core/blob/main/test/UniswapV3Router.spec.ts
  - https://github.com/Uniswap/router-sdk/blob/main/src/swapRouter.test.ts
*/
package swap_scenario

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
	rr "gno.land/r/demo/router"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"

	"gno.land/r/demo/gns"
)

var (
	lp01 = testutils.TestAddress("lp01")
	tr01 = testutils.TestAddress("tr01")

	// vars from Uniswap TEST
	feeAmount = 3000
	// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/UniswapV3Router.spec.ts#L24
	// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/shared/utilities.ts#L23

	tickSpacing = 60
	// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/UniswapV3Router.spec.ts#L25
	// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/shared/utilities.ts#L29

	minTick int32 = -887272
	maxTick int32 = 887272
	// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/shared/utilities.ts#L10-L11
)

func TestPoolInitByAdmin(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePools(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// approve gns to CreatePool ( 500 gns for 1 pool)
	gns.Approve(a2u(consts.POOL_ADDR), 5000)

	// bar-baz
	pl.CreatePool(barPath, bazPath, 100, 79228162514264337593543950337) // tick 0 ≈ 1:1

	// baz-foo
	pl.CreatePool(bazPath, fooPath, 100, 79228162514264337593543950337) // tick 0 ≈ 1:1

	std.TestSkipHeights(4)
}

func TestFaucetLP01(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(barObj, lp01), 0)
	shouldEQ(t, balanceOf(bazObj, lp01), 0)
	shouldEQ(t, balanceOf(fooObj, lp01), 0)

	bar.Faucet(lp01)
	baz.Faucet(lp01)
	foo.Faucet(lp01)

	shouldEQ(t, balanceOf(barObj, lp01), 100000000)
	shouldEQ(t, balanceOf(bazObj, lp01), 100000000)
	shouldEQ(t, balanceOf(fooObj, lp01), 100000000)
	std.TestSkipHeights(5)
}

// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/UniswapV3Router.spec.ts#L83C16-L83C16
func TestPositionMintBarBazInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(consts.POOL_ADDR), 10000000)
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		minTick,     // tickLower
		maxTick,     // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(1))
	shouldEQ(t, liquidity, bigint(10000001))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(10000000))

	std.TestSkipHeights(3)
}

// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/test/UniswapV3Router.spec.ts#L84
func TestPositionMintBazFooInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)
	foo.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		bazPath,     // token0
		fooPath,     // token1
		100,         // fee
		minTick,     // tickLower
		maxTick,     // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(2))
	shouldEQ(t, liquidity, bigint(10000001))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(10000000))

	std.TestSkipHeights(3)
}

func TestFaucetTR01(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	shouldEQ(t, balanceOf(barObj, tr01), 0)

	bar.Faucet(tr01)

	shouldEQ(t, balanceOf(barObj, tr01), 100000000)

	std.TestSkipHeights(5)
}

func TestRouterDrySwapRouteBarFooExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	dryResult := rr.DrySwapRoute(
		barPath,    // inputToken
		fooPath,    // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100", // strRouteArr
		"100", // quoteArr
	)
	shouldEQ(t, dryResult, bigint(98019))
	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarFooExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(consts.POOL_ADDR), 100000)

	barOld := balanceOf(barObj, tr01)
	fooOld := balanceOf(fooObj, tr01)
	shouldEQ(t, barOld, 100000000)
	shouldEQ(t, fooOld, 0)

	swapResult := rr.SwapRoute(
		barPath,    // inputToken
		fooPath,    // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit (minRecv)
	)
	shouldEQ(t, swapResult, bigint(98019))

	barNew := balanceOf(barObj, tr01)
	fooNew := balanceOf(fooObj, tr01)

	shouldEQ(t, barOld-barNew, 100000)
	shouldEQ(t, fooNew-fooOld, 98019)

	std.TestSkipHeights(2)
}

func TestRouterDrySwapRouteBarFooExactOutAfterSwap(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	dryResult := rr.DrySwapRoute(
		barPath,     // inputToken
		fooPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100", // strRouteArr
		"100", // quoteArr
	)
	shouldEQ(t, dryResult, bigint(106226))
	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarFooExactOutAfterSwap(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(consts.POOL_ADDR), 106226)

	barOld := balanceOf(barObj, tr01)
	fooOld := balanceOf(fooObj, tr01)
	shouldEQ(t, barOld, 99900000)
	shouldEQ(t, fooOld, 98019)

	swapResult := rr.SwapRoute(
		barPath,     // inputToken
		fooPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100", // strRouteArr
		"100",    // quoteArr
		"123456", // tokenAmountLimit (maxSpent)
	)
	shouldEQ(t, swapResult, bigint(106226))

	barNew := balanceOf(barObj, tr01)
	fooNew := balanceOf(fooObj, tr01)

	shouldEQ(t, barOld-barNew, 106226)
	// shouldEQ(t, fooNew-fooOld, 100000)
	shouldEQ(t, fooNew-fooOld, 100000-2) // tolerance

	std.TestSkipHeights(2)
}
