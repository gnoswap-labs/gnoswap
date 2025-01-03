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
	"gno.land/r/onbloc/qux"
)

func TestShortWarmUpInternalSmallLiq(t *testing.T) {
	testInit(t)
	testDoubleMint(t)
	testCreatePool(t)
	testMintBarQux100_1(t)
	testMintBarQux100_2(t)
	testStakeToken_1_2(t)
	testNow(t)
	testCollectRewardBoth(t)
}

func testInit(t *testing.T) {
	t.Run("init pool tiers", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// init pool tiers
		// tier 1
		deletePoolTier(t, MUST_EXISTS_IN_TIER_1)
		addPoolTier(t, `gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100`, 1)
		std.TestSkipHeights(1)

		// override warm-up period for testing
		changeWarmup(t, 0, 150)
		changeWarmup(t, 1, 300)
		changeWarmup(t, 2, 900)
		changeWarmup(t, 3, math.MaxInt64)

		// set unstaking fee to 0
		SetUnstakingFeeByAdmin(0)

		// set pool creation fee to 0
		pl.SetPoolCreationFeeByAdmin(0)

		// set community pool distribution to 0% (give it to devOps)
		en.ChangeDistributionPctByAdmin(
			1, 7500,
			2, 2500,
			3, 0,
			4, 0,
		)
	})
}

func testDoubleMint(t *testing.T) {
	t.Run("mint and distribute gns", func(t *testing.T) {
		en.MintAndDistributeGns()
		en.MintAndDistributeGns()

		std.TestSkipHeights(1)
	})
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
	t.Run("mint position 01, bar:qux:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,      // token0
			quxPath,      // token1
			fee100,       // fee
			int32(-1000), // tickLower
			int32(1000),  // tickUpper
			"500000000",  // amount0Desired
			"500000000",  // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)

		uassert.Equal(t, tokenId, uint64(1))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

		gpi := getPrintInfo(t)
		// {"height":"126","time":"1234567896","gns":{"staker":"32106164","devOps":"10702053","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[]}]}

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
			"50",         // amount0Desired
			"50",         // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)

		uassert.Equal(t, tokenId, uint64(2))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

		gpi := getPrintInfo(t)
		// {"height":"127","time":"1234567898","gns":{"staker":"42808219","devOps":"14269404","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[]}]}

		std.TestSkipHeights(1)
	})
}

func testStakeToken_1_2(t *testing.T) {
	t.Run("stake position 01 and 02", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(1))
		StakeToken(1)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)

		gpi := getPrintInfo(t)
		// {"height":"128","time":"1234567900","gns":{"staker":"53510274","devOps":"17836755","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"0","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"},{"lpTokenId":"2","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"0","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}

		std.TestSkipHeights(1)
	})
}

func testNow(t *testing.T) {
	t.Run("now", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gpi := getPrintInfo(t)
		// {"height":"129","time":"1234567902","gns":{"staker":"64212329","devOps":"21404106","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"1","fullAmount":"10702052","ratio":"30","warmUpAmount":"3210615","full30":"10702052","give30":"3210615","penalty30":"7491437","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"},{"lpTokenId":"2","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"1","fullAmount":"1","ratio":"30","warmUpAmount":"0","full30":"1","give30":"0","penalty30":"1","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}

		std.TestSkipHeights(1)
	})
}

func testCollectRewardBoth(t *testing.T) {
	t.Run("collect reward for position 01 and 02", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		CollectReward(1, false)
		CollectReward(2, false)

		gpi := getPrintInfo(t)
		// {"height":"130","time":"1234567904","gns":{"staker":"53510277","devOps":"24971457","communityPool":"14982876","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000006421231"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"2","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"},{"lpTokenId":"2","stakedHeight":"128","stakedTimestamp":"1234567900","stakedDuration":"2","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}

		std.TestSkipHeights(1)
	})
}
