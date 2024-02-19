// single lp, single swap, normal scenario
package swap_scneraio

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/p/demo/common"
	"gno.land/r/demo/consts"

	_ "gno.land/r/demo/grc20_wrapper"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
	rr "gno.land/r/demo/router"
	sr "gno.land/r/demo/staker"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/gnft"
)

var (
	lp01 = testutils.TestAddress("lp01")
	tr01 = testutils.TestAddress("tr01")
)

func TestPoolInitByAdmin(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePools(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// approve gns to CreatePool (500 gns for 1 pool)
	gns.Approve(a2u(consts.POOL_ADDR), 500*10) // x10 pools

	// bar-baz
	pl.CreatePool(barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(29960)) // 1:20

	// baz-foo
	pl.CreatePool(bazPath, fooPath, 100, common.TickMathGetSqrtRatioAtTick(-23030)) // 1:0.1

	// foo-wugnot
	pl.CreatePool(fooPath, wugnotPath, 100, common.TickMathGetSqrtRatioAtTick(-29960)) // 1:0.05

	// gns-wugnot
	pl.CreatePool(gnsPath, wugnotPath, 500, common.TickMathGetSqrtRatioAtTick(0)) // 1:1

	std.TestSkipHeights(5)
}

func TestFaucetLP01(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(barObj, lp01), 0)
	shouldEQ(t, balanceOf(bazObj, lp01), 0)
	shouldEQ(t, balanceOf(fooObj, lp01), 0)
	shouldEQ(t, balanceOf(quxObj, lp01), 0)
	shouldEQ(t, balanceOf(gnsObj, lp01), 0)

	bar.Faucet(lp01)
	baz.Faucet(lp01)
	foo.Faucet(lp01)
	qux.Faucet(lp01)
	gns.Faucet(lp01)

	shouldEQ(t, balanceOf(barObj, lp01), 100000000)
	shouldEQ(t, balanceOf(bazObj, lp01), 100000000)
	shouldEQ(t, balanceOf(fooObj, lp01), 100000000)
	shouldEQ(t, balanceOf(quxObj, lp01), 100000000)
	shouldEQ(t, balanceOf(gnsObj, lp01), 100000000)

	std.TestSkipHeights(5)
}

func TestPositionMintBarBazInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(consts.POOL_ADDR), 10000000)
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		29950,       // tickLower
		29970,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(1))
	shouldEQ(t, liquidity, bigint(4473213901))
	shouldEQ(t, amount0, bigint(499941))
	shouldEQ(t, amoutn1, bigint(10000000))

	std.TestSkipHeights(3)
}

func TestPositionMintBarBazLowerRange(t *testing.T) {
	// lower range ≈ only token1
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(consts.POOL_ADDR), 10000000)
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		29900,       // tickLower
		29910,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(2))
	shouldEQ(t, liquidity, bigint(4484410365))
	shouldEQ(t, amount0, bigint(0))
	shouldEQ(t, amoutn1, bigint(10000000))

	std.TestSkipHeights(3)
}

func TestPositionMintBarBazUpperRange(t *testing.T) {
	// upper range ≈ only token0
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(consts.POOL_ADDR), 10000000)
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		30000,       // tickLower
		32000,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(3))
	shouldEQ(t, liquidity, bigint(470937835))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(0))

	std.TestSkipHeights(3)
}

func TestPositionMintBazFooInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve baz, foo to pool
	baz.Approve(a2u(consts.POOL_ADDR), 10000000)
	foo.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		bazPath,     // token0
		fooPath,     // token1
		100,         // fee
		-23050,      // tickLower
		-23010,      // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(4))
	shouldEQ(t, liquidity, bigint(3163542979))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(999700))

	std.TestSkipHeights(3)
}

func TestPositionMintFooGnotInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// deposit wugnot first
	std.TestIssueCoins(lp01, std.Coins{{"ugnot", 10000000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)

	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	wugnot.Deposit()

	// approve foo, wugnot to pool
	foo.Approve(a2u(consts.POOL_ADDR), 10000000)
	wugnot.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		fooPath,     // token0
		wugnotPath,  // token1
		100,         // fee
		-30960,      // tickLower
		-28960,      // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(5))
	shouldEQ(t, liquidity, bigint(45848242))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(499941))

	std.TestSkipHeights(4)
}

func TestPositionMintGnsGnotInRange(t *testing.T) {
	// INTERNAL INCENTIVE POOL ( gns:gnot:500 staking )
	std.TestSetOrigCaller(lp01)

	// deposit wugnot first
	std.TestIssueCoins(lp01, std.Coins{{"ugnot", 10000000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10000000}}, nil)

	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 10000000)

	wugnot.Deposit()

	// approve gns, wugnot to pool
	gns.Approve(a2u(consts.POOL_ADDR), 10000000)
	wugnot.Approve(a2u(consts.POOL_ADDR), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pn.Mint(
		gnsPath,     // token0
		wugnotPath,  // token1
		500,         // fee
		-1000,       // tickLower
		1000,        // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		MAX_TIMEOUT, // deadline
	)

	shouldEQ(t, tokenId, bigint(6))
	shouldEQ(t, liquidity, bigint(205051663))
	shouldEQ(t, amount0, bigint(10000000))
	shouldEQ(t, amoutn1, bigint(10000000))

	std.TestSkipHeights(4)
}

func TestStakerCreateExternalIncentive(t *testing.T) {
	// get some obl to create external incentive
	std.TestSetOrigCaller(test1)

	// approve obl to staker
	obl.Approve(a2u(consts.STAKER_ADDR), 100000000)

	sr.CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // targetPoolPath
		oblPath,            // rewardTokenPath
		100_000_000,        // rewardAmount
		1234568045,         // startTimestamp
		1234568045+7776000, // endTimestamp ( 90 days )
	)

	std.TestSkipHeights(3)
}

func TestStakerStakeTokenForInternalReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve lpTokenId to staker
	gnft.Approve(a2u(consts.STAKER_ADDR), tid(6))

	// stake tokenId 6
	sr.StakeToken(6)
	std.TestSkipHeights(2)
}

func TestStakerStakeTokenForExternalReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve lpTokenId to staker
	gnft.Approve(a2u(consts.STAKER_ADDR), tid(1))

	// stake tokenId 1
	sr.StakeToken(1)
	std.TestSkipHeights(2)
}

func TestStakerCollectInternalReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(gnsObj, lp01), 90000000)
	shouldEQ(t, balanceOf(oblObj, lp01), 0)

	sr.CollectReward(6)

	shouldEQ(t, balanceOf(gnsObj, lp01), 90003300)
	shouldEQ(t, balanceOf(oblObj, lp01), 0)

	std.TestSkipHeights(1)
}

func TestStakerCollectExternalReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(gnsObj, lp01), 90003300)
	shouldEQ(t, balanceOf(oblObj, lp01), 0)

	sr.CollectReward(1)

	shouldEQ(t, balanceOf(gnsObj, lp01), 90003300)
	shouldEQ(t, balanceOf(oblObj, lp01), 21)

	std.TestSkipHeights(1)
}

func TestFaucetTR01(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	shouldEQ(t, balanceOf(barObj, tr01), 0)
	shouldEQ(t, balanceOf(bazObj, tr01), 0)
	shouldEQ(t, balanceOf(fooObj, tr01), 0)
	shouldEQ(t, balanceOf(quxObj, tr01), 0)

	bar.Faucet(tr01)
	baz.Faucet(tr01)
	foo.Faucet(tr01)
	qux.Faucet(tr01)

	shouldEQ(t, balanceOf(barObj, tr01), 100000000)
	shouldEQ(t, balanceOf(bazObj, tr01), 100000000)
	shouldEQ(t, balanceOf(fooObj, tr01), 100000000)
	shouldEQ(t, balanceOf(quxObj, tr01), 100000000)

	std.TestSkipHeights(5)
}

func TestRouterSwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(consts.POOL_ADDR), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 100000000)
	shouldEQ(t, balanceOf(bazObj, tr01), 100000000)

	swapResult := rr.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
		1,     // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(1999835))

	shouldEQ(t, balanceOf(barObj, tr01), 99900000)
	shouldEQ(t, balanceOf(bazObj, tr01), 101999835)

	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(consts.POOL_ADDR), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 99900000)
	shouldEQ(t, balanceOf(bazObj, tr01), 101999835)

	swapResult := rr.SwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100",  // quoteArr
		100000, // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(5000))

	shouldEQ(t, balanceOf(barObj, tr01), 99895000)
	shouldEQ(t, balanceOf(bazObj, tr01), 102099835)

	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarBazFooWgnotExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(consts.POOL_ADDR), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 99895000)
	shouldEQ(t, wugnotBalanceOf(tr01), 0)

	swapResult := rr.SwapRoute(
		barPath,    // inputToken
		wugnotPath, // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/wugnot:100", // strRouteArr
		"100", // quoteArr
		1,     // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(9979))

	shouldEQ(t, balanceOf(barObj, tr01), 99795000)
	shouldEQ(t, wugnotBalanceOf(tr01), 9979)

	std.TestSkipHeights(2)
}

func TestRouterSwapRouteWgnotFooBazBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// deposit wugnot first
	std.TestIssueCoins(tr01, std.Coins{{"ugnot", 100000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 100000}}, nil)

	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 100000)

	wugnot.Deposit()

	// approve wugnot to pool
	wugnot.Approve(a2u(consts.POOL_ADDR), 100000)

	shouldEQ(t, wugnotBalanceOf(tr01), 109979)
	shouldEQ(t, balanceOf(barObj, tr01), 99795000)

	swapResult := rr.SwapRoute(
		wugnotPath,  // inputToken
		barPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/wugnot:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100",  // quoteArr
		300000, // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(9958))

	shouldEQ(t, balanceOf(barObj, tr01), 99894938)
	shouldEQ(t, wugnotBalanceOf(tr01), 100021)

	std.TestSkipHeights(3)
}

func TestPositionCollectFeeLpTokenId_1(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pn.CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, amount0, bigint(19))
	shouldEQ(t, amount1, bigint(200))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")

	std.TestSkipHeights(1)
}

// tokenId 2, 3 is out of range

func TestPositionCollectFeeLpTokenId_4(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pn.CollectFee(4)
	shouldEQ(t, tokenId, uint64(4))
	shouldEQ(t, amount0, bigint(199))
	shouldEQ(t, amount1, bigint(20))
	shouldEQ(t, poolPath, "gno.land/r/demo/baz:gno.land/r/demo/foo:100")

	std.TestSkipHeights(1)
}

func TestPositionCollectFeeLpTokenId_5(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pn.CollectFee(5)
	shouldEQ(t, tokenId, uint64(5))
	shouldEQ(t, amount0, bigint(19))
	shouldEQ(t, amount1, bigint(0))
	shouldEQ(t, poolPath, "gno.land/r/demo/foo:gno.land/r/demo/wugnot:100")

	std.TestSkipHeights(1)
}

func TestPositionBurnStakedPosition(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	shouldPanic(t, func() { pn.Burn(1) })
	// can not burn staked position ( unstake first)

	std.TestSkipHeights(1)
}

func TestStakerUnstake(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// it will return unstaked position's poolPath, amount0, amount1 ( not reward )
	poolPath, amount0, amount1 := sr.UnstakeToken(1)
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, amount0, bigint(604982))
	shouldEQ(t, amount1, bigint(7899135))

	std.TestSkipHeights(1)
}

func TestPositionBurnUnstakedPosition(t *testing.T) {
	tokenId, liquidity, amount0, amount1, poolPath := pn.Burn(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, liquidity, bigint(4473213901))
	shouldEQ(t, amount0, bigint(604982))
	shouldEQ(t, amount1, bigint(7899135))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")

	std.TestSkipHeights(1)
}

func TestStakerEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSkipHeights(1382371)

	shouldEQ(t, balanceOf(oblObj, test1), 499999900000000)

	shouldPanic(t,
		func() {
			sr.EndExternalIncentive(string(test1), "gno.land/r/demo/bar:gno.land/r/demo/baz:100", "gno.land/r/demo/obl")
		})
	std.TestSkipHeights(1234567)

	sr.EndExternalIncentive(string(test1), "gno.land/r/demo/bar:gno.land/r/demo/baz:100", "gno.land/r/demo/obl")

	shouldEQ(t, balanceOf(oblObj, test1), 499999999999979)
}
