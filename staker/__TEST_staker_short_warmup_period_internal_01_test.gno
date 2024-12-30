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

		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":126,"time":1234567896,"gns":{"staker":0,"devOps":8561643,"communityPool":34246574,"govStaker":0,"protocolFee":200000000,"GnoswapAdmin":99999800000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":0,"position":[]}]}`)

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

		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":127,"time":1234567898,"gns":{"staker":0,"devOps":11415524,"communityPool":45662099,"govStaker":0,"protocolFee":200000000,"GnoswapAdmin":99999800000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":0,"position":[]}]}`)
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

		// accu all warm up periods
		// positionRewards := calcPositionReward(uint64(std.GetHeight()), 1)
		// rewardPerWarmUp, penaltyPerWarmUp, rewardPerIncentivePerWarmUp, penaltyPertIncentivePerWarmUp := positionRewards.Internal, positionRewards.InternalPenalty, positionRewards.External, positionRewards.ExternalPenalty

		positionRewards := calcPositionRewardByWarmups(uint64(std.GetHeight()), 1)
		for _, reward := range positionRewards {
			// println(reward.Internal)
			// println(reward.InternalPenalty)
			// println(reward.External)
			// println(reward.ExternalPenalty)
		}

		// staker minted ≈ 10702054
		// uassert.Equal(t, uint64(6421232), rewardPerWarmUp[0]) // reward for 30%

		// println("rewardPerWarmUp")
		// println(rewardPerWarmUp)
		// println()
		// println("penaltyPerWarmUp")
		// println(penaltyPerWarmUp)
		// println(" >> sum", rewardPerWarmUp+penaltyPerWarmUp)
		// println()
		// println("rewardPerIncentivePerWarmUp")
		// println(rewardPerIncentivePerWarmUp)
		// println()
		// println("penaltyPertIncentivePerWarmUp")
		// println(penaltyPertIncentivePerWarmUp)
		// println()
	})
}

func testSetPoolTier(t *testing.T) {
	t.Run("set pool tier", func(t *testing.T) {

		std.TestSetRealm(adminRealm)
		addPoolTier(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)
		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":129,"time":1234567902,"gns":{"staker":10702055,"devOps":17123286,"communityPool":57791094,"govStaker":0,"protocolFee":200000000,"GnoswapAdmin":99999800000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":10702055,"position":[{"lpTokenId":1,"stakedHeight":128,"stakedTimestamp":1234567900,"stakedDuration":1,"fullAmount":10702055,"ratio":30,"warmUpAmount":3210616,"full30":10702055,"give30":3210616,"full50":0,"give50":0,"full70":0,"give70":0,"full100":0}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","startTimestamp":1234567902,"tier":2,"numPoolSameTier":1,"poolReward":0,"position":[]}]}`)

		std.TestSkipHeights(1)
	})
}

func testStakeToken_2(t *testing.T) {
	t.Run("stake token 2", func(t *testing.T) {

		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)

		// gpi := GetPrintInfo()
		// uassert.Equal(t, gpi, `{"height":130,"time":1234567904,"gns":{"staker":18193494,"devOps":19977167,"communityPool":61715180,"govStaker":0,"protocolFee":200000000,"GnoswapAdmin":99999800000000},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","startTimestamp":1234567890,"tier":1,"numPoolSameTier":1,"poolReward":18193493,"position":[{"lpTokenId":1,"stakedHeight":128,"stakedTimestamp":1234567900,"stakedDuration":2,"fullAmount":18193493,"ratio":30,"warmUpAmount":5458047,"full30":18193493,"give30":5458047,"full50":0,"give50":0,"full70":0,"give70":0,"full100":0}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","startTimestamp":1234567902,"tier":2,"numPoolSameTier":1,"poolReward":0,"position":[{"lpTokenId":2,"stakedHeight":130,"stakedTimestamp":1234567904,"stakedDuration":0,"fullAmount":0,"ratio":0,"warmUpAmount":0,"full30":0,"give30":0,"full50":0,"give50":0,"full70":0,"give70":0,"full100":0}]}]}`)

		std.TestSkipHeights(1)

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
}
