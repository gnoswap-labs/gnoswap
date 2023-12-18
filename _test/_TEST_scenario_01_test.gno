package swap_scneraio

import (
	"encoding/gjson"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"

	"gno.land/r/demo/users"

	_ "gno.land/r/demo/grc20_wrapper"

	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"
	rou "gno.land/r/demo/router"
	stk "gno.land/r/demo/staker"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/qux"

	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"

	"gno.land/r/demo/gnft"
)

var (
	test1 = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")
	lp01  = testutils.TestAddress("lp01")
	tr01  = testutils.TestAddress("tr01")

	poolAddr     = std.DerivePkgAddr("gno.land/r/demo/pool")
	positionAddr = std.DerivePkgAddr("gno.land/r/demo/position")
	stakerAddr   = std.DerivePkgAddr("gno.land/r/demo/staker")
	routerAddr   = std.DerivePkgAddr("gno.land/r/demo/router")

	barPath = "gno.land/r/demo/bar"
	bazPath = "gno.land/r/demo/baz"
	fooPath = "gno.land/r/demo/foo"
	quxPath = "gno.land/r/demo/qux"

	wugnotPath = "gno.land/r/demo/wugnot"

	gnsPath = "gno.land/r/demo/gns"
	oblPath = "gno.land/r/demo/obl"

	barObj = bar.GetGRC20()
	bazObj = baz.GetGRC20()
	fooObj = foo.GetGRC20()
	quxObj = qux.GetGRC20()

	gnsObj = gns.GetGRC20()
	oblObj = obl.GetGRC20()

	max_timeout = bigint(9999999999)
)

func TestPoolInitByAdmin(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestFaucetTEST1(t *testing.T) {
	std.TestSetOrigCaller(test1)

	shouldEQ(t, balanceOf(barObj, test1), 0)
	shouldEQ(t, balanceOf(bazObj, test1), 0)
	shouldEQ(t, balanceOf(fooObj, test1), 0)
	shouldEQ(t, balanceOf(quxObj, test1), 0)
	shouldEQ(t, balanceOf(gnsObj, test1), 0)

	bar.Faucet()
	baz.Faucet()
	foo.Faucet()
	qux.Faucet()

	gns.Faucet()

	shouldEQ(t, balanceOf(barObj, test1), 1000000000)
	shouldEQ(t, balanceOf(bazObj, test1), 1000000000)
	shouldEQ(t, balanceOf(fooObj, test1), 1000000000)
	shouldEQ(t, balanceOf(quxObj, test1), 1000000000)
	shouldEQ(t, balanceOf(gnsObj, test1), 1000000000)

	std.TestSkipHeights(5)
}

func TestPoolCreatePools(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// approve gns to CreatePool ( 500 gns for 1 pool)
	gns.Approve(a2u(poolAddr), 5000)

	// bar-baz
	pl.CreatePool(barPath, bazPath, 100, 354340008410679467268648495215) // tick 29960 ≈ 1:20

	// baz-foo
	pl.CreatePool(bazPath, fooPath, 100, 25050389945027294416741547334) // tick -23030 ≈ 1:0.1

	// foo-wugnot
	pl.CreatePool(fooPath, wugnotPath, 100, 17714911063927984461157312042) // tick -29960 ≈ 1:0.05

	std.TestSkipHeights(4)
}

func TestFaucetLP01(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(barObj, lp01), 0)
	shouldEQ(t, balanceOf(bazObj, lp01), 0)
	shouldEQ(t, balanceOf(fooObj, lp01), 0)
	shouldEQ(t, balanceOf(quxObj, lp01), 0)

	bar.Faucet()
	baz.Faucet()
	foo.Faucet()
	qux.Faucet()

	shouldEQ(t, balanceOf(barObj, lp01), 1000000000)
	shouldEQ(t, balanceOf(bazObj, lp01), 1000000000)
	shouldEQ(t, balanceOf(fooObj, lp01), 1000000000)
	shouldEQ(t, balanceOf(quxObj, lp01), 1000000000)

	std.TestSkipHeights(5)
}

func TestPositionMintBarBazInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(poolAddr), 10000000)
	baz.Approve(a2u(poolAddr), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pos.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		29950,       // tickLower
		29970,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, tokenId, bigint(1))
	shouldEQ(t, liquidity, bigint(4473213900))
	shouldEQ(t, amount0, bigint(499941))
	shouldEQ(t, amoutn1, bigint(9999999))

	std.TestSkipHeights(3)
}

func TestPositionMintBarBazLowerRange(t *testing.T) {
	// lower range ≈ only token1
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(poolAddr), 10000000)
	baz.Approve(a2u(poolAddr), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pos.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		29900,       // tickLower
		29910,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, tokenId, bigint(2))
	shouldEQ(t, liquidity, bigint(4484410364))
	shouldEQ(t, amount0, bigint(0))
	shouldEQ(t, amoutn1, bigint(9999999))

	std.TestSkipHeights(3)
}

func TestPositionMintBarBazUpperRange(t *testing.T) {
	// upper range ≈ only token0
	std.TestSetOrigCaller(lp01)

	// approve bar, baz to pool ( position.Mint() calls pool.Mint() ≈ so approve to pool )
	bar.Approve(a2u(poolAddr), 10000000)
	baz.Approve(a2u(poolAddr), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pos.Mint(
		barPath,     // token0
		bazPath,     // token1
		100,         // fee
		30000,       // tickLower
		32000,       // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, tokenId, bigint(3))
	shouldEQ(t, liquidity, bigint(470937834))
	shouldEQ(t, amount0, bigint(9999999))
	shouldEQ(t, amoutn1, bigint(0))

	std.TestSkipHeights(3)
}

func TestPositionMintBazFooInRange(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve baz, foo to pool
	baz.Approve(a2u(poolAddr), 10000000)
	foo.Approve(a2u(poolAddr), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pos.Mint(
		bazPath,     // token0
		fooPath,     // token1
		100,         // fee
		-23050,      // tickLower
		-23010,      // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, tokenId, bigint(4))
	shouldEQ(t, liquidity, bigint(3163542978))
	shouldEQ(t, amount0, bigint(9999999))
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
	foo.Approve(a2u(poolAddr), 10000000)
	wugnot.Approve(a2u(poolAddr), 10000000)

	tokenId, liquidity, amount0, amoutn1 := pos.Mint(
		fooPath,     // token0
		wugnotPath,  // token1
		100,         // fee
		-30960,      // tickLower
		-28960,      // tickUpper
		10000000,    // amount0Desired
		10000000,    // amount1Desired
		0,           // amount0Min
		0,           // amount1Min
		max_timeout, // deadline
	)

	shouldEQ(t, tokenId, bigint(5))
	shouldEQ(t, liquidity, bigint(45848241))
	shouldEQ(t, amount0, bigint(9999999))
	shouldEQ(t, amoutn1, bigint(499941))

	std.TestSkipHeights(4)
}

func TestStakerCreateExternalIncentive(t *testing.T) {
	/*
		// tier 1 for INTERNAL REWARD
		poolTiers["gno.land/r/demo/gns:gno.land/r/demo/wugnot:500"] = 1
		poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 1 // dev
	*/

	// get some obl to create external incentive
	std.TestSetOrigCaller(test1)
	shouldEQ(t, balanceOf(oblObj, test1), 0)
	obl.Faucet()
	shouldEQ(t, balanceOf(oblObj, test1), 1000000000)

	// approve obl to staker
	obl.Approve(a2u(stakerAddr), 1000000000)

	stk.CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // targetPoolPath
		oblPath,            // rewardTokenPath
		1000000000,         // rewardAmount
		1234568045,         // startTimestamp
		1234568045+7776000, // endTimestamp ( 90 days )
	)

	std.TestSkipHeights(3)
}

func TestStakerStakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// approve lpTokenId to staker
	gnft.Approve(a2u(stakerAddr), tid(1))

	// stake tokenId 1
	stk.StakeToken(1)
	std.TestSkipHeights(3)
}

func TestStakerApiGetRewardsByAddress(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// test1 reward check
	gra := stk.ApiGetRewardByAddress(lp01)
	jsonStr := gjson.Parse(gra)

	responseArr := jsonStr.Get("response.data").Array()
	shouldEQ(t, len(responseArr), 2)

	shouldEQ(t, responseArr[0].Get("incentiveType").String(), "INTERNAL")
	shouldEQ(t, responseArr[0].Get("targetPoolPath").String(), "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, responseArr[0].Get("rewardTokenPath").String(), "gno.land/r/demo/gns")
	shouldEQ(t, responseArr[0].Get("rewardTokenAmount").Int(), 1650)

	shouldEQ(t, responseArr[1].Get("incentiveType").String(), "EXTERNAL")
	shouldEQ(t, responseArr[1].Get("targetPoolPath").String(), "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, responseArr[1].Get("rewardTokenPath").String(), "gno.land/r/demo/obl")
	shouldEQ(t, responseArr[1].Get("rewardTokenAmount").Int(), 212)
}

func TestStakerCollectReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	shouldEQ(t, balanceOf(gnsObj, lp01), 0)
	shouldEQ(t, balanceOf(oblObj, lp01), 0)

	stk.CollectReward(1)

	shouldEQ(t, balanceOf(gnsObj, lp01), 1650)
	shouldEQ(t, balanceOf(oblObj, lp01), 212)
}

func TestStakerApiGetRewardsByAddressAfterCollectReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// test1 reward check
	gra := stk.ApiGetRewardByAddress(lp01)
	jsonStr := gjson.Parse(gra)

	responseArr := jsonStr.Get("response.data").Array()
	shouldEQ(t, len(responseArr), 0) // should be 0, since CollectReward() did collet everything

	std.TestSkipHeights(1)
}

func TestStakerApiGetRewardsByAddressAfterBunchOfTime(t *testing.T) {
	std.TestSkipHeights(864000 / 5) // 10 day

	std.TestSetOrigCaller(lp01)

	// test1 reward check
	gra := stk.ApiGetRewardByAddress(lp01)
	jsonStr := gjson.Parse(gra)

	responseArr := jsonStr.Get("response.data").Array()
	shouldEQ(t, len(responseArr), 2)

	shouldEQ(t, responseArr[0].Get("incentiveType").String(), "INTERNAL")
	shouldEQ(t, responseArr[0].Get("targetPoolPath").String(), "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, responseArr[0].Get("rewardTokenPath").String(), "gno.land/r/demo/gns")
	shouldEQ(t, responseArr[0].Get("rewardTokenAmount").Int(), 2200)

	shouldEQ(t, responseArr[1].Get("incentiveType").String(), "EXTERNAL")
	shouldEQ(t, responseArr[1].Get("targetPoolPath").String(), "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, responseArr[1].Get("rewardTokenPath").String(), "gno.land/r/demo/obl")
	shouldEQ(t, responseArr[1].Get("rewardTokenAmount").Int(), 282)

	std.TestSkipHeights(1)
}

func TestFaucetTR01(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	shouldEQ(t, balanceOf(barObj, tr01), 0)
	shouldEQ(t, balanceOf(bazObj, tr01), 0)
	shouldEQ(t, balanceOf(fooObj, tr01), 0)
	shouldEQ(t, balanceOf(quxObj, tr01), 0)

	bar.Faucet()
	baz.Faucet()
	foo.Faucet()
	qux.Faucet()

	shouldEQ(t, balanceOf(barObj, tr01), 1000000000)
	shouldEQ(t, balanceOf(bazObj, tr01), 1000000000)
	shouldEQ(t, balanceOf(fooObj, tr01), 1000000000)
	shouldEQ(t, balanceOf(quxObj, tr01), 1000000000)

	std.TestSkipHeights(5)
}

func TestRouterSwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(poolAddr), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 1000000000)
	shouldEQ(t, balanceOf(bazObj, tr01), 1000000000)

	swapResult := rou.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
		1,     // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(1999835))

	shouldEQ(t, balanceOf(barObj, tr01), 999900000)
	shouldEQ(t, balanceOf(bazObj, tr01), 1001999835)

	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(poolAddr), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 999900000)
	shouldEQ(t, balanceOf(bazObj, tr01), 1001999835)

	swapResult := rou.SwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100",  // quoteArr
		100000, // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(5000))

	shouldEQ(t, balanceOf(barObj, tr01), 999895000)
	shouldEQ(t, balanceOf(bazObj, tr01), 1002099834)

	std.TestSkipHeights(2)
}

func TestRouterSwapRouteBarBazFooWgnotExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	// approve bar to pool
	bar.Approve(a2u(poolAddr), 100000)

	shouldEQ(t, balanceOf(barObj, tr01), 999895000)
	shouldEQ(t, wugnotBalanceOf(tr01), 0)

	swapResult := rou.SwapRoute(
		barPath,    // inputToken
		wugnotPath, // outputToken
		100000,     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/wugnot:100", // strRouteArr
		"100", // quoteArr
		1,     // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(9979))

	shouldEQ(t, balanceOf(barObj, tr01), 999795000)
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
	wugnot.Approve(a2u(poolAddr), 100000)

	shouldEQ(t, wugnotBalanceOf(tr01), 109979)
	shouldEQ(t, balanceOf(barObj, tr01), 999795000)

	swapResult := rou.SwapRoute(
		wugnotPath,  // inputToken
		barPath,     // outputToken
		100000,      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/wugnot:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100",  // quoteArr
		300000, // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(199900))

	shouldEQ(t, balanceOf(barObj, tr01), 999894999)
	shouldEQ(t, wugnotBalanceOf(tr01), 99995)

	std.TestSkipHeights(3)
}

func TestPositionCollectFeeLpTokenId_1(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pos.CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, amount0, bigint(19))
	shouldEQ(t, amount1, bigint(198))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")

	std.TestSkipHeights(1)
}

// tokenId 2, 3 is out of range

func TestPositionCollectFeeLpTokenId_4(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pos.CollectFee(4)
	shouldEQ(t, tokenId, uint64(4))
	shouldEQ(t, amount0, bigint(199))
	shouldEQ(t, amount1, bigint(18))
	shouldEQ(t, poolPath, "gno.land/r/demo/baz:gno.land/r/demo/foo:100")

	std.TestSkipHeights(1)
}

func TestPositionCollectFeeLpTokenId_5(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tokenId, amount0, amount1, poolPath := pos.CollectFee(5)
	shouldEQ(t, tokenId, uint64(5))
	shouldEQ(t, amount0, bigint(19))
	shouldEQ(t, amount1, bigint(0))
	shouldEQ(t, poolPath, "gno.land/r/demo/foo:gno.land/r/demo/wugnot:100")

	std.TestSkipHeights(1)
}

func TestPositionBurnStakedPosition(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	shouldPanic(t, func() { pos.Burn(1) })
	// can not burn staked position ( unstake first)

	std.TestSkipHeights(1)
}

func TestStakerUnstake(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// it will return unstaked position's poolPath, amount0, amount1 ( not reward )
	poolPath, amount0, amount1 := stk.UnstakeToken(1)
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")
	shouldEQ(t, amount0, bigint(604921))
	shouldEQ(t, amount1, bigint(7900364))

	std.TestSkipHeights(1)
}

func TestPositionBurnUnstakedPosition(t *testing.T) {
	tokenId, liquidity, amount0, amount1, poolPath := pos.Burn(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, liquidity, bigint(4473213900))
	shouldEQ(t, amount0, bigint(604921))
	shouldEQ(t, amount1, bigint(7900364))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/baz:100")

	std.TestSkipHeights(1)
}

func TestStakerEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSkipHeights(1382371)

	shouldEQ(t, balanceOf(oblObj, test1), 0)

	shouldPanic(t,
		func() {
			stk.EndExternalIncentive(string(test1), "gno.land/r/demo/bar:gno.land/r/demo/baz:100", "gno.land/r/demo/obl")
		})
	std.TestSkipHeights(1)

	stk.EndExternalIncentive(string(test1), "gno.land/r/demo/bar:gno.land/r/demo/baz:100", "gno.land/r/demo/obl")
	std.TestSkipHeights(1)

	shouldEQ(t, balanceOf(oblObj, test1), 999999506)
}

func balanceOf(token *grc20.AdminToken, addr std.Address) uint64 {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}

	return balance
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}

func wugnotBalanceOf(addr std.Address) uint64 {
	return wugnot.BalanceOf(a2u(addr))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
