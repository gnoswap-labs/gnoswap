package position

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	pl "gno.land/r/gnoswap/v2/pool"
	pn "gno.land/r/gnoswap/v2/position"
	pr "gno.land/r/gnoswap/v2/router"
)

var (
	user1Adderss = testutils.TestAddress("user1")
	user1Realm   = std.NewUserRealm(user1Adderss)
	user2Adderss = testutils.TestAddress("user2")
	user2Realm   = std.NewUserRealm(user2Adderss)
	tickSpacing  = int32(60)
	minTick      = (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick      = (consts.MAX_TICK / tickSpacing) * tickSpacing

	poolCreationFee = uint64(100_000_000)
)

/*
This test demonstrates a issue(Gnoswap-19) fee collection mechanism. The key steps are:

· Create a pool and add liquidity from two different users
· Perform swaps to generate fees in the pool
· Burn 0 liquidity to update fees
· Collect fees for both users
· Compare the collected fees between the two users
*/
func TestCollectFeeWithTwoUser(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)
	common.SetLimitCaller(true)
	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	pl.CreatePool(barPath, bazPath, 3000, "25054144837504793118641380156") // encodePriceSqrt(1, 10)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"

	t.Run("mint and swap fee should be distributed pro rata user's liquidity", func(t *testing.T) {
		std.TestSetRealm(gsaRealm)
		std.TestSetOrigCaller(gsa)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

		pool := pl.GetPool(barPath, bazPath, 3000)

		std.TestSetRealm(gsaRealm)
		tokenId_res1, liquidity_res1, amount0_res1, amount1_res1 := pn.Mint(
			barPath,                // token0 string,
			bazPath,                // token1 string,
			3000,                   // fee uint32,
			minTick,                // tickLower int32,
			maxTick,                // tickUpper int32,
			"10000000",             // _amount0Desired string, // *u256.Uint // 100e18
			"10000000",             // _amount1Desired string, // *u256.Uint // 100e18
			"0",                    // _amount0Min string, // *u256.Uint
			"0",                    // _amount1Min string, // *u256.Uint
			time.Now().Unix()+1000, // deadline int64,
			user1Adderss.String(),  // mintTo string
		)

		std.TestSetRealm(gsaRealm)
		tokenId_res2, liquidity_res2, amount0_res2, amount1_res2 := pn.Mint(
			barPath,                // token0 string,
			bazPath,                // token1 string,
			3000,                   // fee uint32,
			minTick,                // tickLower int32,
			maxTick,                // tickUpper int32,
			"10000000",             // _amount0Desired string, // *u256.Uint // 100e18
			"10000000",             // _amount1Desired string, // *u256.Uint // 100e18
			"0",                    // _amount0Min string, // *u256.Uint
			"0",                    // _amount1Min string, // *u256.Uint
			time.Now().Unix()+1000, // deadline int64,
			user2Adderss.String(),  // mintTo string
		)

		// ====== Swap to accrue fees ======
		pr.SwapRoute(
			barPath,                     //inputToken string,
			bazPath,                     //outputToken string,
			"10000000",                  //_amountSpecified string, // int256
			"EXACT_IN",                  //swapType string,
			barPath+":"+bazPath+":3000", //strRouteArr string, // []string
			"100",                       //quoteArr string, // []int
			"0",                         //_tokenAmountLimit string, // uint256
		)

		pr.SwapRoute(
			bazPath,                     //inputToken string,
			barPath,                     //outputToken string,
			"10000000",                  //_amountSpecified string, // int256
			"EXACT_IN",                  //swapType string,
			bazPath+":"+barPath+":3000", //strRouteArr string, // []string
			"100",                       //quoteArr string, // []int
			"0",                         //_tokenAmountLimit string, // uint256
		)

		// ====== Burn 0 to update fee ======
		std.TestSetRealm(posRealm)
		pl.Burn(
			barPath,      // token0Path string,
			bazPath,      // token1Path string,
			uint32(3000), // fee uint32,
			minTick,      // tickLower int32,
			maxTick,      // tickUpper int32,
			"0",          // _liquidityAmount string, // uint128
		)

		// ====== Collect fees and copare ======
		// user1
		std.TestSetRealm(user1Realm)
		std.TestSetOrigCaller(user1Adderss)
		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		userBarBalanceBeforeCollect_1 := bar.BalanceOf(a2u(user1Adderss))
		userBazBalanceBeforeCollect_1 := baz.BalanceOf(a2u(user1Adderss))
		tokenId_res3, withoutFee0_res3, withoutFee1_res3, positionPoolKey_res3, _, _ := pn.CollectFee(tokenId_res1, false)
		userBarBalanceAfterCollect_1 := bar.BalanceOf(a2u(user1Adderss))
		userBazBalanceAfterCollect_1 := baz.BalanceOf(a2u(user1Adderss))

		// user2
		std.TestSetRealm(user2Realm)
		std.TestSetOrigCaller(user2Adderss)
		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		userBarBalanceBeforeCollect_2 := bar.BalanceOf(a2u(user2Adderss))
		userBazBalanceBeforeCollect_2 := baz.BalanceOf(a2u(user2Adderss))
		tokenId_res4, withoutFee0_res4, withoutFee1_res4, positionPoolKey_res4, _, _ := pn.CollectFee(tokenId_res2, false)
		userBarBalanceAfterCollect_2 := bar.BalanceOf(a2u(user2Adderss))
		userBazBalanceAfterCollect_2 := baz.BalanceOf(a2u(user2Adderss))
		shouldEQ(t, (userBarBalanceAfterCollect_1-userBarBalanceBeforeCollect_1)-(userBarBalanceAfterCollect_2-userBarBalanceBeforeCollect_2), uint64(0))
		shouldEQ(t, (userBazBalanceAfterCollect_1-userBazBalanceBeforeCollect_1)-(userBazBalanceAfterCollect_2-userBazBalanceBeforeCollect_2), uint64(0))
	})
}
