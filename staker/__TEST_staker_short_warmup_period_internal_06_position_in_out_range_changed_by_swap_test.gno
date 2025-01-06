package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	rr "gno.land/r/gnoswap/v1/router"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var poolPath string = "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"

func TestShortWarmUpInternalPositionInOutRangeChangedBySwap(t *testing.T) {
	testInit(t)
	testCreatePool(t)
	testMintBarQux100_1(t)
	testMintBarQux100_2(t)
	testStakeToken_1_2(t)
	testMakePosition1OutRange(t)
	// testCheckRewardAfter1Block(t)
}

func testInit(t *testing.T) {
	t.Run("initialize", func(t *testing.T) {
		deletePoolTier(t, MUST_EXISTS_IN_TIER_1)

		addPoolTier(t, poolPath, 1)
		std.TestSkipHeights(1)

		changeWarmup(t, 0, 901)
		changeWarmup(t, 1, 301)
		changeWarmup(t, 2, 151)
		changeWarmup(t, 3, 1)
	})
}

func testCreatePool(t *testing.T) {
	t.Run("create pool", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

		pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")

		std.TestSkipHeights(1)
	})
}

func testMintBarQux100_1(t *testing.T) {
	t.Run("mint position 01, bar:qux:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,    // token0
			quxPath,    // token1
			fee100,     // fee
			int32(-30), // tickLower
			int32(30),  // tickUpper
			"50",       // amount0Desired
			"50",       // amount1Desired
			"1",        // amount0Min
			"1",        // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)

		uassert.Equal(t, tokenId, uint64(1))
		// uassert.Equal(t, gnft.OwnerOf(tid(tokenId)), admin)

		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":125,"time":1234567894,"gns":{"staker":0,"devOps":5707762,"communityPool":22831049,"govStaker":0,"protocolFee":100000000,"GnoswapAdmin":99999900000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":0,"position":[]}]}`)

		std.TestSkipHeights(1)
	})
}

func testMintBarQux100_2(t *testing.T) {
	t.Run("mint position 02, bar:qux:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,      // token0
			quxPath,      // token1
			fee100,       // fee
			int32(-1000), // tickLower
			int32(1000),  // tickUpper
			"50000",      // amount0Desired
			"50000",      // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)

		uassert.Equal(t, tokenId, uint64(2))
		// uassert.Equal(t, gnft.OwnerOf(tid(tokenId)), admin)

		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":126,"time":1234567896,"gns":{"staker":0,"devOps":8561643,"communityPool":34246574,"govStaker":0,"protocolFee":100000000,"GnoswapAdmin":99999900000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":0,"position":[]}]}`)

		std.TestSkipHeights(1)
	})
}

func testStakeToken_1_2(t *testing.T) {
	t.Run("stake position 01, 02", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(GetOrigPkgAddr(), tid(1))
		StakeToken(1)

		gnft.Approve(GetOrigPkgAddr(), tid(2))
		StakeToken(2)

		std.TestSkipHeights(1)
	})
}

// XXX
func testMakePosition1OutRange(t *testing.T) {
	t.Run("make position 01 out of range", func(t *testing.T) {
		poolTick := pl.PoolGetSlot0Tick(poolPath)
		uassert.Equal(t, poolTick, int32(0))

		// ROUTER SWAP
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

		// PANIC: ./staker: test pkg: panic: runtime error: invalid memory address or nil pointer dereference
		tokenIn, tokenOut := rr.ExactInSwapRoute(
			barPath,
			quxPath,
			"10000",
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			"100",
			"0",
			max_timeout,
		)
		uassert.Equal(t, tokenIn, "10000")
		uassert.Equal(t, tokenOut, "-9884")
		std.TestSkipHeights(1)
	})
}

// XXX
func testCheckRewardAfter1Block(t *testing.T) {
	// t.Run("check reward after 1 block", func(t *testing.T) {
	// 	poolTick := pl.PoolGetSlot0Tick(poolPath)
	// 	uassert.Equal(t, poolTick, int32(-194))
	// 	// AT THIS POINT position #1 is out of range

	// 	lpToken01Rewards := ApiGetRewardsByLpTokenId(1)
	// 	uassert.Equal(t, lpToken01Rewards, `{"stat":{"height":129,"timestamp":1234567902},"response":[{"lpTokenId":1,"address":"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d","rewards":[{"incentiveType":"INTERNAL","incentiveId":"","targetPoolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","rewardTokenPath":"gno.land/r/gnoswap/v1/gns","rewardTokenAmount":101175,"stakeTimestamp":1234567898,"stakeHeight":127,"incentiveStart":1234567898}]}]}`)

	// 	lpToken02Rewards := ApiGetRewardsByLpTokenId(2)
	// 	uassert.Equal(t, lpToken02Rewards, `{"stat":{"height":129,"timestamp":1234567902},"response":[{"lpTokenId":2,"address":"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d","rewards":[{"incentiveType":"INTERNAL","incentiveId":"","targetPoolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","rewardTokenPath":"gno.land/r/gnoswap/v1/gns","rewardTokenAmount":6320056,"stakeTimestamp":1234567898,"stakeHeight":127,"incentiveStart":1234567898}]}]}`)

	// POSITION #1 PREVIOUS REWARD
	// `{"stat":{"height":128,"timestamp":1234567900},"response":[{"lpTokenId":1,"address":"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d","rewards":[{"incentiveType":"INTERNAL","incentiveId":"","targetPoolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","rewardTokenPath":"gno.land/r/gnoswap/v1/gns","rewardTokenAmount":101175,"stakeTimestamp":1234567898,"stakeHeight":127,"incentiveStart":1234567898}]}]}`)

	// POSITION #2 PREVIOUS REWARD
	// `{"stat":{"height":128,"timestamp":1234567900},"response":[{"lpTokenId":2,"address":"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d","rewards":[{"incentiveType":"INTERNAL","incentiveId":"","targetPoolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","rewardTokenPath":"gno.land/r/gnoswap/v1/gns","rewardTokenAmount":3109440,"stakeTimestamp":1234567898,"stakeHeight":127,"incentiveStart":1234567898}]}]}`)

	/*
		PREVIOUS REWARD -> NOW
		- POSITION #1
			101175 > 101175
		- POSITION #2
			3109440 > 6320056
	*/
	// })
}
