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

func TestShortWarmUpRemoveTier(t *testing.T) {
	testInit(t)
	testDoubleMint(t)
	testPoolInitCreatePool(t)
	testMintBarQux100_1(t)
	testMintBarBaz100_2(t)
	testSkip100Height(t)
	testStakeToken_1(t)
	testSetPoolTier(t)
	testStakeToken_2(t)
	testNow(t)
	testRemovePoolTier(t)
	testNow2(t)
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

func testPoolInitCreatePool(t *testing.T) {
	t.Run("create pool", func(t *testing.T) {

		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

		pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
		pl.CreatePool(barPath, bazPath, 3000, "79228162514264337593543950337")

		std.TestSkipHeights(1)
	})
}

func testMintBarQux100_1(t *testing.T) {
	t.Run("mint bar:qux:100", func(t *testing.T) {
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

		gpi := getPrintInfo(t)
		// {"height":"126","time":"1234567896","gns":{"staker":"32106164","devOps":"10702053","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[]}]}

		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100_2(t *testing.T) {
	t.Run("mint bar:baz:3000", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

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

		uassert.Equal(t, tokenId, uint64(2))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

		gpi := getPrintInfo(t)
		// {"height":"127","time":"1234567898","gns":{"staker":"42808219","devOps":"14269404","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[]}]}

		std.TestSkipHeights(1)
	})
}

func testSkip100Height(t *testing.T) {
	t.Run("skip 100 heights", func(t *testing.T) {
		std.TestSkipHeights(100)

		gpi := getPrintInfo(t)
		// {"height":"228","time":"1234568100","gns":{"staker":"1123715724","devOps":"374571905","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[]}]}

		std.TestSkipHeights(1)
	})
}

func testStakeToken_1(t *testing.T) {
	t.Run("stake token 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(1))
		StakeToken(1)

		gpi := getPrintInfo(t)
		// {"height":"229","time":"1234568102","gns":{"staker":"1134417779","devOps":"378139256","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"0","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}

		std.TestSkipHeights(1)
	})
}

func testSetPoolTier(t *testing.T) {
	t.Run("set pool tier", func(t *testing.T) {
		std.TestSkipHeights(100) // this reward should go to bar:qux:100

		std.TestSetRealm(adminRealm)
		addPoolTier(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)

		gpi := getPrintInfo(t)
		// {"height":"330","time":"1234568304","gns":{"staker":"2215325284","devOps":"738441757","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"2","numPoolSameTier":"2","position":[]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"101","fullAmount":"1080907453","ratio":"30","warmUpAmount":"324272236","full30":"1080907453","give30":"324272236","penalty30":"756635217","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}

		std.TestSkipHeights(1)
	})
}

func testStakeToken_2(t *testing.T) {
	t.Run("stake token 02", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)

		gpi := getPrintInfo(t)
		// {"height":"331","time":"1234568306","gns":{"staker":"2226027339","devOps":"742009108","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"2","numPoolSameTier":"2","position":[{"lpTokenId":"2","stakedHeight":"331","stakedTimestamp":"1234568306","stakedDuration":"0","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"102","fullAmount":"764126573","ratio":"30","warmUpAmount":"229237972","full30":"764126573","give30":"229237972","penalty30":"534888601","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}
		std.TestSkipHeights(1)
	})
}

func testNow(t *testing.T) {
	t.Run("now", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gpi := getPrintInfo(t)
		// {"height":"332","time":"1234568308","gns":{"staker":"2236729394","devOps":"745576459","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"2","numPoolSameTier":"2","position":[{"lpTokenId":"2","stakedHeight":"331","stakedTimestamp":"1234568306","stakedDuration":"1","fullAmount":"3210615","ratio":"30","warmUpAmount":"963184","full30":"3210615","give30":"963184","penalty30":"2247431","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"103","fullAmount":"771618010","ratio":"30","warmUpAmount":"231485403","full30":"771618010","give30":"231485403","penalty30":"540132607","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}
		std.TestSkipHeights(1)
	})
}

func testRemovePoolTier(t *testing.T) {
	t.Run("remove pool tier", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		deletePoolTier(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000")

		gpi := getPrintInfo(t)
		// {"height":"333","time":"1234568310","gns":{"staker":"2247431449","devOps":"749143810","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"0","numPoolSameTier":"0","position":[{"lpTokenId":"2","stakedHeight":"331","stakedTimestamp":"1234568306","stakedDuration":"2","fullAmount":"6421231","ratio":"30","warmUpAmount":"1926369","full30":"6421231","give30":"1926369","penalty30":"4494862","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"104","fullAmount":"779109447","ratio":"30","warmUpAmount":"233732834","full30":"779109447","give30":"233732834","penalty30":"545376613","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}
		std.TestSkipHeights(1)
	})
}

func testNow2(t *testing.T) {
	t.Run("now 2", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gpi := getPrintInfo(t)
		// {"height":"334","time":"1234568312","gns":{"staker":"2258133504","devOps":"752711161","communityPool":"0","govStaker":"0","protocolFee":"0","GnoswapAdmin":"100000000000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"0","numPoolSameTier":"0","position":[{"lpTokenId":"2","stakedHeight":"331","stakedTimestamp":"1234568306","stakedDuration":"3","fullAmount":"6421231","ratio":"30","warmUpAmount":"1926369","full30":"6421231","give30":"1926369","penalty30":"4494862","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"229","stakedTimestamp":"1234568102","stakedDuration":"105","fullAmount":"799443352","ratio":"30","warmUpAmount":"239833005","full30":"799443352","give30":"239833005","penalty30":"559610347","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}
		std.TestSkipHeights(1)
	})
}
