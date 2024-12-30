package staker

import (
	"math"
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var testGnsBalanceTracker gnsBalanceTracker

func TestShortWarmUpInternal(t *testing.T) {
	testInit(t)
	testDoubleMint(t)
	testCreatePool(t)
	testMintBarQux100_1(t)
	testMintBarBaz100_2(t)
	testStakeToken_1(t)
	testSetPoolTier(t)
	testStakeToken_2(t)
}

func testInit(t *testing.T) {
	t.Run("init pool tiers", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// init pool tiers
		// tier 1
		// delete(poolTiers, MUST_EXISTS_IN_TIER_1)
		deletePoolTier(t, MUST_EXISTS_IN_TIER_1)

		// poolTiers["gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"] = InternalTier{
		// 	tier:           1,
		// 	startTimestamp: time.Now().Unix(),
		// }
		addPoolTier(t, `gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100`, 1)

		// override warm-up period for testing
		// warmUp[100] = 901 // 30m ~
		// warmUp[70] = 301  // 10m ~ 30m
		// warmUp[50] = 151  // 5m ~ 10m
		// warmUp[30] = 1    // ~ 5m
		changeWarmup(t, 0, 150)
		changeWarmup(t, 1, 300)
		changeWarmup(t, 2, 900)
		changeWarmup(t, 3, math.MaxInt64)

		// set unstaking fee to 0
		SetUnstakingFeeByAdmin(0)

		// set community pool distribution to 0% ( give it to devOps)
		en.ChangeDistributionPctByAdmin(
			1, 7500,
			2, 2500,
			3, 0,
			4, 0,
		)
	})
}

func testDoubleMint(t *testing.T) {
	en.MintAndDistributeGns()
	en.MintAndDistributeGns()

	std.TestSkipHeights(1)
}

func testCreatePool(t *testing.T) {
	t.Run("create pool", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

		pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
		pl.CreatePool(barPath, bazPath, 3000, "79228162514264337593543950337")

		std.TestSkipHeights(1)
	})
}

func testMintBarQux100_1(t *testing.T) {
	t.Run("mint bar qux 100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,      // token0
			quxPath,      // token1
			fee100,       // fee
			int32(-1000), // tickLower
			int32(1000),  // tickUpper
			"50",         // amount0Desired
			"50",         // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)

		uassert.Equal(t, tokenId, uint64(1))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100_2(t *testing.T) {
	t.Run("mint bar baz 100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		testGnsBalanceTracker = gnsBalanceCheck(t, testGnsBalanceTracker, false)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,      // token0
			bazPath,      // token1
			fee3000,      // fee
			int32(-1020), // tickLower
			int32(1020),  // tickUpper
			"50",         // amount0Desired
			"50",         // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)

		uassert.Equal(t, tokenId, uint64(2))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

		testGnsBalanceTracker = gnsBalanceCheck(t, testGnsBalanceTracker, true)
	})
}

func testStakeToken_1(t *testing.T) {
	t.Run("stake token 1", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		testGnsBalanceTracker = gnsBalanceCheck(t, testGnsBalanceTracker, false)

		gnft.Approve(consts.STAKER_ADDR, tid(1))
		StakeToken(1)
		std.TestSkipHeights(1)

		testGnsBalanceTracker = gnsBalanceCheck(t, testGnsBalanceTracker, true)

		// 1 block passed
		beforeUserGnsBalance := gns.BalanceOf(admin)
		beforeCommunityPoolGnsBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))

		CollectReward(1, false)
		std.TestSkipHeights(1)
		// staker will get about 10702054 per block
		// position #1 is in 30% warm up period
		// 10702054 * 0.3 = 3210616 (claimable)
		// 10702054 * 0.7 = 7491437.8 (internal penalty goes to community pool)

		afterUserGnsBalance := gns.BalanceOf(admin)
		afterCommunityPoolGnsBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))

		userDiff := afterUserGnsBalance - beforeUserGnsBalance
		uassert.True(t, isInErrorRange(userDiff, 3210616))

		communityPoolDiff := afterCommunityPoolGnsBalance - beforeCommunityPoolGnsBalance
		uassert.True(t, isInErrorRange(communityPoolDiff, 7491437))
	})
}

func testSetPoolTier(t *testing.T) {
	t.Run("set pool tier", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		addPoolTier(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)
		std.TestSkipHeights(1)
	})
}

func testStakeToken_2(t *testing.T) {
	t.Run("stake token 2", func(t *testing.T) {

		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)
		std.TestSkipHeights(10)

		// CollectReward(1, false)
		// CollectReward(2, false)

		// gpi := getPrintInfo()
		// uassert.Equal(t, gpi, `{"height":130,"time":1234567904,"gns":{"staker":18193494,"devOps":19977167,"communityPool":61715180,"govStaker":0,"protocolFee":200000000,"GnoswapAdmin":99999800000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":18193493,"position":[{"lpTokenId":1,"stakedHeight":128,"stakedTimestamp":1234567900,"stakedDuration":2,"fullAmount":18193493,"ratio":30,"warmUpAmount":5458047,"full30":18193493,"give30":5458047,"full50":0,"give50":0,"full70":0,"give70":0,"full100":0}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","startTimestamp":1234567902,"tier":2,"numPoolSameTier":1,"poolReward":0,"position":[{"lpTokenId":2,"stakedHeight":130,"stakedTimestamp":1234567904,"stakedDuration":0,"fullAmount":0,"ratio":0,"warmUpAmount":0,"full30":0,"give30":0,"full50":0,"give50":0,"full70":0,"give70":0,"full100":0}]}]}`)

		// std.TestSkipHeights(1)

		/*
			소문자
			calcPositionReward

			웜업별
			- 리워드
			- 페널티
			- 익스터널 리워드
			- 익스터널 페널티
			- 마지막 시점부터
		*/

		// std.TestSkipHeights(1)
		// calcPositionReward(uint64(std.GetHeight()), 1)
	})

	t.Run("check reward for position 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		resStr := getPrintInfo(t)
		println(resStr)

		// 	rewards := calcPositionRewardByWarmups(uint64(std.GetHeight()), 1)
		// 	// for _, reward := range rewards {
		// 	// 	println("total internal", reward.Internal)
		// 	// 	println("total internal penalty", reward.InternalPenalty)
		// 	// 	println("total external", reward.External)
		// 	// 	println("total external penalty", reward.ExternalPenalty)
		// 	// 	println()
		// 	// }
	})

	// t.Run("check reward for position 02", func(t *testing.T) {
	// 	std.TestSetRealm(adminRealm)

	// 	rewards := calcPositionRewardByWarmups(uint64(std.GetHeight()), 2)
	// 	// for _, reward := range rewards {
	// 	// 	println("total internal", reward.Internal)
	// 	// 	println("total internal penalty", reward.InternalPenalty)
	// 	// 	println("total external", reward.External)
	// 	// 	println("total external penalty", reward.ExternalPenalty)
	// 	// 	println()
	// 	// }
	// })
}
