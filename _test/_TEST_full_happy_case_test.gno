// 1 LP
// 1 SWAP
// HAPPY CASES
package swap_scenario

import (
	"std"
	"testing"
	"time"

	// gnoswap contract
	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
	rr "gno.land/r/demo/router"
	sr "gno.land/r/demo/staker"

	// gnoswap setting
	"gno.land/p/demo/common"
	"gno.land/r/demo/consts"

	// grc20
	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns" // internal reward
	"gno.land/r/demo/obl" // external reward
	"gno.land/r/demo/qux"
	"gno.land/r/demo/wugnot"

	// grc721
	"gno.land/r/demo/gnft"

	// gnoland
	"gno.land/p/demo/testutils"
)

var (
	lp01 = testutils.TestAddress("lp01") // liquidity provider
	tr01 = testutils.TestAddress("tr01") // trader
)

// DEBUGs
// func init() {
// 	println("lp01:", lp01)
// 	println("tr01:", tr01)
// }

func TestFaucetLP01(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	shouldEQ(t, foo.BalanceOf(a2u(lp01)), 0)
	shouldEQ(t, bar.BalanceOf(a2u(lp01)), 0)
	shouldEQ(t, baz.BalanceOf(a2u(lp01)), 0)
	shouldEQ(t, qux.BalanceOf(a2u(lp01)), 0)
	shouldEQ(t, gns.BalanceOf(a2u(lp01)), 0)

	foo.Faucet(lp01)
	bar.Faucet(lp01)
	baz.Faucet(lp01)
	qux.Faucet(lp01)
	gns.Faucet(lp01)

	shouldEQ(t, foo.BalanceOf(a2u(lp01)), 100_000_000)
	shouldEQ(t, bar.BalanceOf(a2u(lp01)), 100_000_000)
	shouldEQ(t, baz.BalanceOf(a2u(lp01)), 100_000_000)
	shouldEQ(t, qux.BalanceOf(a2u(lp01)), 100_000_000)
	shouldEQ(t, gns.BalanceOf(a2u(lp01)), 100_000_000)

	std.TestSkipHeights(5)
}

func TestFaucetTR01(t *testing.T) {
	std.TestSetPrevAddr(tr01)

	shouldEQ(t, bar.BalanceOf(a2u(tr01)), 0)
	shouldEQ(t, baz.BalanceOf(a2u(tr01)), 0)
	shouldEQ(t, foo.BalanceOf(a2u(tr01)), 0)
	shouldEQ(t, qux.BalanceOf(a2u(tr01)), 0)

	bar.Faucet(tr01)
	baz.Faucet(tr01)
	foo.Faucet(tr01)
	qux.Faucet(tr01)

	shouldEQ(t, bar.BalanceOf(a2u(tr01)), 100_000_000)
	shouldEQ(t, baz.BalanceOf(a2u(tr01)), 100_000_000)
	shouldEQ(t, foo.BalanceOf(a2u(tr01)), 100_000_000)
	shouldEQ(t, qux.BalanceOf(a2u(tr01)), 100_000_000)

	std.TestSkipHeights(5)
}

func TestAllowStakerToDistributeInternalReward(t *testing.T) {
	std.TestSetPrevAddr(consts.INTERNAL_REWARD_ACCOUNT)
	gns.Approve(a2u(consts.STAKER_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(1)
}

func TestPoolInitManual(t *testing.T) {
	std.TestSetPrevAddr(consts.GNOSWAP_ADMIN) // this address will be registered as admin

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePool(t *testing.T) {
	std.TestSetPrevAddr(test1)

	// user > pool || approve pool creation fee
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE*4)

	// bar-baz
	pl.CreatePool(barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(29960).ToString()) // 1:20

	// baz-foo
	pl.CreatePool(bazPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(-23030).ToString()) // 1:0.1

	// foo-wugnot
	pl.CreatePool(fooPath, consts.WRAPPED_WUGNOT, fee100, common.TickMathGetSqrtRatioAtTick(-29960).ToString()) // 1:0.05

	// gns-wugnot
	pl.CreatePool(consts.GNS_PATH, consts.WRAPPED_WUGNOT, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString()) // 1:1

	std.TestSkipHeights(5)
}

func TestPositionMint_BarBazInRange(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	// user > pool || approve pair of token to pool
	// - position.Mint() calls pool.Mint() ≈ approve to pool
	bar.Approve(a2u(consts.POOL_ADDR), 50_000_000)
	baz.Approve(a2u(consts.POOL_ADDR), 50_000_000)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,                      // token0
		bazPath,                      // token1
		fee100,                       // fee
		29950,                        // tickLower
		29970,                        // tickUpper
		"50000000",                   // amount0Desired (50_000_000)
		"50000000",                   // amount1Desired (50_000_000)
		"0",                          // amount0Min
		"0",                          // amount1Min
		max_timeout,                  // deadline
		std.GetOrigCaller().String(), // mintTo
	)
	shouldEQ(t, lpTokenId, 1)
	shouldEQ(t, liquidity, "22366069500")
	shouldEQ(t, amount0, "2499706")
	shouldEQ(t, amount1, "49999999")

	std.TestSkipHeights(3)
}

func TestPositionMint_BarBazLowerRange(t *testing.T) {
	// lower range == only token1 will be minted

	std.TestSetPrevAddr(lp01)
	bar.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	baz.Approve(a2u(consts.POOL_ADDR), 10_000_000)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,
		bazPath,
		fee100,
		29900,
		29910,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, lpTokenId, 2)
	shouldEQ(t, liquidity, "4484410364")
	shouldEQ(t, amount0, "0")
	shouldEQ(t, amount1, "9999999")

	std.TestSkipHeights(3)
}

func TestPositionMint_BarBazUpperrRange(t *testing.T) {
	// upper range == only token0 will be minted

	std.TestSetPrevAddr(lp01)
	bar.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	baz.Approve(a2u(consts.POOL_ADDR), 10_000_000)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,
		bazPath,
		fee100,
		30000,
		32000,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, lpTokenId, 3)
	shouldEQ(t, liquidity, "470937834")
	shouldEQ(t, amount0, "10000000")
	shouldEQ(t, amount1, "0")

	std.TestSkipHeights(3)
}

func TestPositionMint_BazFooInRange(t *testing.T) {
	std.TestSetPrevAddr(lp01)
	baz.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	foo.Approve(a2u(consts.POOL_ADDR), 10_000_000)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		bazPath,
		fooPath,
		fee100,
		-23050,
		-23010,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, lpTokenId, 4)
	shouldEQ(t, liquidity, "3163542978")
	shouldEQ(t, amount0, "10000000")
	shouldEQ(t, amount1, "999700")

	poolToken0 := pl.PoolGetToken0BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	poolToken1 := pl.PoolGetToken1BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	shouldEQ(t, poolToken0, "10000000")
	shouldEQ(t, poolToken1, "999700")
	std.TestSkipHeights(3)
}

func TestPositionIncreaseLiquidity_BazFoo(t *testing.T) {
	std.TestSetPrevAddr(lp01)
	baz.Approve(a2u(consts.POOL_ADDR), 1_000_000)
	foo.Approve(a2u(consts.POOL_ADDR), 1_000_000)

	lpTokenId, liquidity, amount0, amount1 := pn.IncreaseLiquidity(
		4,           // lpTokenId
		"1000000",   // amount0Desired
		"1000000",   // amount1Desired
		"0",         // amount0Min
		"0",         // amount1Min
		max_timeout, // deadline
	)
	shouldEQ(t, lpTokenId, 4)
	shouldEQ(t, liquidity, "316354297")
	shouldEQ(t, amount0, "1000000")
	shouldEQ(t, amount1, "99970")

	poolToken0 := pl.PoolGetToken0BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	poolToken1 := pl.PoolGetToken1BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	shouldEQ(t, poolToken0, "11000000")
	shouldEQ(t, poolToken1, "1099670")
	std.TestSkipHeights(3)
}

func TestPositionDecreaseLiquidity_BazFooPartial(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	lpTokenId, liquidity, fee0, amount0, fee1, amount1, poolPath := pn.DecreaseLiquidity(
		4,           // lpTokenId
		50,          // liquidityRatio
		"0",         // amount0Min
		"0",         // amount1Min
		max_timeout, // deadline
		false,
	)
	shouldEQ(t, lpTokenId, 4)
	shouldEQ(t, liquidity, "1739948637")
	shouldEQ(t, fee0, "0")
	shouldEQ(t, amount0, "0")
	shouldEQ(t, fee1, "5499999")
	shouldEQ(t, amount1, "549835")
	shouldEQ(t, poolPath, "gno.land/r/demo/baz:gno.land/r/demo/foo:100")

	poolToken0 := pl.PoolGetToken0BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	poolToken1 := pl.PoolGetToken1BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	shouldEQ(t, poolToken0, "5500001")
	shouldEQ(t, poolToken1, "549835")
	std.TestSkipHeights(3)
}

func TestPositionMint_FooGnotInRange(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	// user > pool || approve pair of token to pool
	// - position.Mint() calls pool.Mint() ≈ approve to pool
	foo.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	wugnot.Approve(a2u(consts.POOL_ADDR), 10_000_000)

	// user > position || approve wugnot
	// - position will automatically wrap user sent gnot
	// - wrapped amount can be left and position will automatically unwrap it
	wugnot.Approve(a2u(consts.POSITION_ADDR), 10_000_000)

	std.TestSkipHeights(3)

	// user > position || send 10_000_000 ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	std.TestIssueCoins(lp01, std.Coins{{"ugnot", 10_000_000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10_000_000}}, nil)
	testBanker.SendCoins(lp01, consts.POSITION_ADDR, std.Coins{{"ugnot", 10_000_000}})

	oldUserWugnot := wugnotBalance(lp01)
	shouldEQ(t, oldUserWugnot, 0)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		fooPath,
		consts.GNOT,
		fee100,
		-30960,
		-28960,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, lpTokenId, 5)
	shouldEQ(t, liquidity, "45848241")
	shouldEQ(t, amount0, "10000000")
	shouldEQ(t, amount1, "499941")

	newUserWugnotBalance := wugnotBalance(lp01)
	shouldEQ(t, newUserWugnotBalance, 0) // all left wugnot should be unwrapped

	std.TestSkipHeights(1)
}

func TestPositionMint_GnsGnotInRange(t *testing.T) {
	// GNS:GNOT:3000 is INTERNAL INCENTIVE POOL
	std.TestSetPrevAddr(lp01)

	gns.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	wugnot.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	wugnot.Approve(a2u(consts.POSITION_ADDR), 10_000_000)
	std.TestSkipHeights(3)

	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	std.TestIssueCoins(lp01, std.Coins{{"ugnot", 10_000_000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 10_000_000}}, nil)
	testBanker.SendCoins(lp01, consts.POSITION_ADDR, std.Coins{{"ugnot", 10_000_000}})

	oldUserWugnot := wugnotBalance(lp01)
	shouldEQ(t, oldUserWugnot, 0)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		consts.GNS_PATH,
		consts.GNOT,
		fee3000,
		-1020,
		1020,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		std.GetOrigCaller().String(),
	)
	shouldEQ(t, lpTokenId, 6)
	shouldEQ(t, liquidity, "201130731")
	shouldEQ(t, amount0, "10000000")
	shouldEQ(t, amount1, "9999999")

	newUserWugnotBalance := wugnotBalance(lp01)
	shouldEQ(t, newUserWugnotBalance, 0) // all left wugnot should be unwrapped

	std.TestSkipHeights(1)
}

func TestStakerCreateExternalIncentive(t *testing.T) {
	std.TestSetPrevAddr(test1)

	// user > staker || approve external reward token
	obl.Approve(a2u(consts.STAKER_ADDR), 100_000_000)

	sr.CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // targetPoolPath
		oblPath,                   // rewardTokenPath
		"100000000",               // rewardAmount
		time.Now().Unix(),         // startTimestamp,
		time.Now().Unix()+7776000, // endTimestamp (+90 days)
	)

	std.TestSkipHeights(2)
}

func TestStakerMintAndStake_ExternalReward(t *testing.T) {
	// one click mint & stake lpToken for `external reward` pool
	std.TestSetPrevAddr(lp01)

	bar.Approve(a2u(consts.POOL_ADDR), 10_000_000)
	baz.Approve(a2u(consts.POOL_ADDR), 10_000_000)

	lpTokenId, liquidity, amount0, amount1, poolPath := sr.MintAndStake(
		barPath,     // token0
		bazPath,     // token1
		fee100,      // fee
		19960,       // tickLower
		39960,       // tickUpper
		"10000000",  // amount0Desired
		"10000000",  // amount1Desired
		"0",         // amount0Min
		"0",         // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, lpTokenId, 7)
	shouldEQ(t, liquidity, "5682837")
	shouldEQ(t, amount0, "499941")
	shouldEQ(t, amount1, "9999999")

	std.TestSkipHeights(3)
}

func TestStakerStakeToken_InternalReward(t *testing.T) {
	// stake lpToken for `internal reward` pool
	std.TestSetPrevAddr(lp01)

	// user > staker || approve lpToken to stake
	gnft.Approve(a2u(consts.STAKER_ADDR), "6")
	sr.StakeToken(6) // GNS:GNOT:3000

	std.TestSkipHeights(2)
}

func TestRouterDrySwapRoute_BarBazExactIn(t *testing.T) {
	// just dry ≈ no need to set caller

	dryResult := rr.DrySwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
	)
	shouldEQ(t, dryResult, "19996361")

	std.TestSkipHeights(1)
}

func TestRouterSwapRoute_BarBazExactIn(t *testing.T) {
	std.TestSetPrevAddr(tr01)

	// user > pool || approve input token
	bar.Approve(a2u(consts.POOL_ADDR), 1_000_000)

	// user > router || approve output token for 0.15% fee
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	gsaOldBaz := baz.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	swapResult := rr.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit (minRecv)
	)
	shouldEQ(t, swapResult, "19966367")

	std.TestSkipHeights(3)

	// 0.15% fee
	gsaNewBaz := baz.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldBaz < gsaNewBaz, true)
}

func TestRouterDrySwapRoute_BarBazExactOut(t *testing.T) {
	dryResult := rr.DrySwapRoute(
		barPath,
		bazPath,
		"1999836",
		"EXACT_OUT",
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100",
		"100",
	)
	shouldEQ(t, dryResult, "100032")

	std.TestSkipHeights(1)
}

func TestRouterSwapRoute_BarBazExactOut(t *testing.T) {
	std.TestSetPrevAddr(tr01)

	bar.Approve(a2u(consts.POOL_ADDR), 1_999_836)

	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	userOldBaz := baz.BalanceOf(a2u(tr01))
	gsaOldBaz := baz.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	swapResult := rr.SwapRoute(
		barPath,
		bazPath,
		"1999836",
		"EXACT_OUT",
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100",
		"100",
		"108041",
	)
	shouldEQ(t, swapResult, "100032") // swapResult userSend

	userNewBaz := baz.BalanceOf(a2u(tr01))
	shouldEQ(t, userNewBaz-userOldBaz, 1996837) // swapResult userRecv

	std.TestSkipHeights(3)

	// 0.15% fee
	gsaNewBaz := baz.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldBaz < gsaNewBaz, true)
}

func TestRouterDrySwapRoute_GnotGnsExactIn(t *testing.T) {
	dryResult := rr.DrySwapRoute(
		consts.GNOT,
		consts.GNS_PATH,
		"100000",
		"EXACT_IN",
		"gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000",
		"100",
	)
	shouldEQ(t, dryResult, "99650")

	std.TestSkipHeights(1)
}

func TestRouterSwapRoute_GnotGnsExactIn(t *testing.T) {
	// target pool is gns:gnot:3000
	// but this swap test swaps gnot > gns
	std.TestSetPrevAddr(tr01)

	// user > pool || approve input token
	wugnot.Approve(a2u(consts.POOL_ADDR), 100_000)
	// user > pool || approve input token, to refund left wrapped gnot
	wugnot.Approve(a2u(consts.ROUTER_ADDR), 100_000)

	// user > router || approve output token for 0.15% fee
	gns.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	// user > router || send 100_000 ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	std.TestIssueCoins(tr01, std.Coins{{"ugnot", 100_000}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 100_000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 100_000)
	testBanker.SendCoins(lp01, consts.ROUTER_ADDR, std.Coins{{"ugnot", 100_000}})

	gsaOldGns := gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	swapResult := rr.SwapRoute(
		consts.GNOT,
		consts.GNS_PATH,
		"100000",
		"EXACT_IN",
		"gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000",
		"100",
		"1",
	)
	shouldEQ(t, swapResult, "99501")

	std.TestSkipHeights(3)

	// 0.15% fee
	gsaNewGns := gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldGns < gsaNewGns, true)
}

func TestRouterDrySwapRoute_GnsGnotExactIn(t *testing.T) {
	dryResult := rr.DrySwapRoute(
		consts.GNS_PATH,
		consts.GNOT,
		"50000",
		"EXACT_IN",
		"gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000",
		"100",
	)
	shouldEQ(t, dryResult, "49887")

	std.TestSkipHeights(1)
}

func TestRouterSwapRoute_GnsGnotExactIn(t *testing.T) {
	std.TestSetPrevAddr(tr01) // has 99_501 of gns

	gns.Approve(a2u(consts.POOL_ADDR), 50_000)
	wugnot.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	gsaOldWugnot := wugnot.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	swapResult := rr.SwapRoute(
		consts.GNS_PATH,
		consts.GNOT,
		"50000",
		"EXACT_IN",
		"gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000",
		"100",
		"1",
	)
	shouldEQ(t, swapResult, "49813")

	std.TestSkipHeights(3)

	// 0.15% fee
	gsaNewWugnot := gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldWugnot < gsaNewWugnot, true)
}

func TestPositionCollectFee_LpTokenId1(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	gsaOldBar := bar.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	lpTokenId, amount0, amount1, poolPath := pn.CollectFee(1)
	shouldEQ(t, lpTokenId, 1)
	shouldEQ(t, amount0, "107")
	shouldEQ(t, amount1, "0")
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")

	std.TestSkipHeights(1)

	// 1% fee
	// if user collected fee is less than 100, 1% of fee is not collected since it's 0
	gsaNewBar := bar.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldBar < gsaNewBar, true)

	std.TestSkipHeights(1)
}

func TestStakerCollectReward_LpTokenId6_Internal(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	lp01OldGns := gns.BalanceOf(a2u(lp01))
	gsaOldGns := gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	oldOwner := gnft.OwnerOf("6")

	// SKIP BUNCH OF TIME
	// 1H = 720
	// 1D = 17280
	// 1M = 30D = 518400
	std.TestSkipHeights(17280)
	sr.CollectReward(6)

	lp01NewGns := gns.BalanceOf(a2u(lp01))
	gsaNewGns := gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	newOwner := gnft.OwnerOf("6")

	shouldEQ(t, lp01OldGns < lp01NewGns, true)
	shouldEQ(t, gsaOldGns < gsaNewGns, true)
	shouldEQ(t, oldOwner, newOwner)

	std.TestSkipHeights(1)
}

func TestStakerUnstakeToken_LpTokenId7_External(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	gsaOldObl := obl.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	poolPath, amount0, amount1 := sr.UnstakeToken(7)
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, amount0, "500220")
	shouldEQ(t, amount1, "9994411")

	gsaNewObl := obl.BalanceOf(a2u(consts.GNOSWAP_ADMIN))
	shouldEQ(t, gsaOldObl < gsaNewObl, true)

	std.TestSkipHeights(1)
}

func TestPositionDecreaseLiquidity_BazFooFull(t *testing.T) {
	std.TestSetPrevAddr(lp01)

	lpTokenId, liquidity, fee0, amount0, fee1, amount1, poolPath := pn.DecreaseLiquidity(
		4,           // lpTokenId
		100,         // liquidityRatio
		"0",         // amount0Min
		"0",         // amount1Min
		max_timeout, // deadline
		false,
	)
	shouldEQ(t, lpTokenId, 4)
	shouldEQ(t, liquidity, "1739948638")
	shouldEQ(t, fee0, "0")
	shouldEQ(t, amount0, "0")
	shouldEQ(t, fee1, "5499999")
	shouldEQ(t, amount1, "549835")
	shouldEQ(t, poolPath, "gno.land/r/demo/baz:gno.land/r/demo/foo:100")

	poolToken0 := pl.PoolGetToken0BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	poolToken1 := pl.PoolGetToken1BalanceStr("gno.land/r/demo/baz:gno.land/r/demo/foo:100")
	shouldEQ(t, poolToken0, "2")
	shouldEQ(t, poolToken1, "0")
	std.TestSkipHeights(3)
}

func TestEndExternalIncentive(t *testing.T) {
	std.TestSetPrevAddr(test1)

	userOldObl := obl.BalanceOf(a2u(test1))

	// skip bunch of time to end external incentive
	std.TestSkipHeights(4000000)
	sr.EndExternalIncentive(
		test1,
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100",
		oblPath,
	)

	userNewObl := obl.BalanceOf(a2u(test1))
	shouldEQ(t, userOldObl < userNewObl, true)

	std.TestSkipHeights(1)
}
