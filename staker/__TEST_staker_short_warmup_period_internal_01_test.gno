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
	testMintBarQux100Pos01(t)
	testMintBarBaz100Pos02(t)
	testStakeTokenPos01(t)
	checkReward(t)
	testSetPoolTier(t)
	testStakeTokenPos02(t)
}

func testInit(t *testing.T) {
	t.Run("init pool tiers", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// init pool tiers
		// tier 1
		// bar:qux:100 is only in tier 1
		deletePoolTier(t, MUST_EXISTS_IN_TIER_1)
		addPoolTier(t, `gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100`, 1)

		// override warm-up period for testing
		changeWarmup(t, 0, 150)
		changeWarmup(t, 1, 300)
		changeWarmup(t, 2, 900)
		changeWarmup(t, 3, math.MaxInt64)

		// set unstaking fee to 0
		SetUnstakingFeeByAdmin(0)

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

func testMintBarQux100Pos01(t *testing.T) {
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

func testMintBarBaz100Pos02(t *testing.T) {
	t.Run("mint bar baz 100", func(t *testing.T) {
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
		std.TestSkipHeights(1)

		uassert.Equal(t, tokenId, uint64(2))
		uassert.Equal(t, gnft.MustOwnerOf(tid(tokenId)), adminAddr)

	})
}

func testStakeTokenPos01(t *testing.T) {
	t.Run("stake token 1", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(1))
		StakeToken(1)
		std.TestSkipHeights(1)

		expected := `{"height":"128","time":"1234567915","gns":{"staker":"53510274","devOps":"17836755","communityPool":"0","govStaker":"0","protocolFee":"200000000","GnoswapAdmin":"99999800000000"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"127","stakedTimestamp":"1234567910","stakedDuration":"1","fullAmount":"10702053","ratio":"30","warmUpAmount":"3210616","full30":"10702053","give30":"3210616","penalty30":"7491437","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}`
		/*
			{
			  "height": "128",
			  "time": "1234567915",
			  "gns": {
			    "staker": "53510274",
			    "devOps": "17836755",
			    "communityPool": "0",
			    "govStaker": "0",
			    "protocolFee": "200000000",
			    "GnoswapAdmin": "99999800000000"
			  },
			  "pool": [
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			      "tier": "1",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "1",
			          "stakedHeight": "127",
			          "stakedTimestamp": "1234567910",
			          "stakedDuration": "1",
			          "fullAmount": "10702053",
			          "ratio": "30",
			          "warmUpAmount": "3210616",
			          "full30": "10702053",
			          "give30": "3210616",
			          "penalty30": "7491437",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    }
			  ]
			}
		*/
		internalRewards := getPrintInfo(t)
		uassert.Equal(t, internalRewards, expected)
	})
}

func checkReward(t *testing.T) {
	t.Run("collect reward", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		beforeUserGnsBalance := gns.BalanceOf(admin)
		beforeCommunityPoolGnsBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))

		CollectReward(1, false)
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

	t.Run("check reward after collecting (same block)", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		expected := `{"height":"128","time":"1234567915","gns":{"staker":"42808221","devOps":"17836755","communityPool":"7491437","govStaker":"0","protocolFee":"200000000","GnoswapAdmin":"99999803210616"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"127","stakedTimestamp":"1234567910","stakedDuration":"1","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}`
		internalRewards := getPrintInfo(t)
		uassert.Equal(t, internalRewards, expected)
		/*
			{
			  "height": "128",
			  "time": "1234567915",
			  "gns": {
			    "staker": "42808221",
			    "devOps": "17836755",
			    "communityPool": "7491437",
			    "govStaker": "0",
			    "protocolFee": "200000000",
			    "GnoswapAdmin": "99999803210616"
			  },
			  "pool": [
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			      "tier": "1",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "1",
			          "stakedHeight": "127",
			          "stakedTimestamp": "1234567910",
			          "stakedDuration": "1",
			          "fullAmount": "0",
			          "ratio": "30",
			          "warmUpAmount": "0",
			          "full30": "0",
			          "give30": "0",
			          "penalty30": "0",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    }
			  ]
			}
		*/

		beforeUserGnsBalance := gns.BalanceOf(admin)
		beforeCommunityPoolGnsBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))

		// collect reward requested in same block
		// no reward should be collected
		CollectReward(1, false)

		afterUserGnsBalance := gns.BalanceOf(admin)
		afterCommunityPoolGnsBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))

		uassert.Equal(t, afterUserGnsBalance, beforeUserGnsBalance)
		uassert.Equal(t, afterCommunityPoolGnsBalance, beforeCommunityPoolGnsBalance)

	})

	t.Run("check reward after collecting (next block)", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		std.TestSkipHeights(1)

		expected := `{"height":"129","time":"1234567920","gns":{"staker":"53510276","devOps":"21404106","communityPool":"7491437","govStaker":"0","protocolFee":"200000000","GnoswapAdmin":"99999803210616"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"127","stakedTimestamp":"1234567910","stakedDuration":"2","fullAmount":"10702053","ratio":"30","warmUpAmount":"3210616","full30":"10702053","give30":"3210616","penalty30":"7491437","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}`
		internalRewards := getPrintInfo(t)
		uassert.Equal(t, internalRewards, expected)
		/*
			{
			  "height": "129",
			  "time": "1234567920",
			  "gns": {
			    "staker": "53510276",
			    "devOps": "21404106",
			    "communityPool": "7491437",
			    "govStaker": "0",
			    "protocolFee": "200000000",
			    "GnoswapAdmin": "99999803210616"
			  },
			  "pool": [
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			      "tier": "1",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "1",
			          "stakedHeight": "127",
			          "stakedTimestamp": "1234567910",
			          "stakedDuration": "2",
			          "fullAmount": "10702053",
			          "ratio": "30",
			          "warmUpAmount": "3210616",
			          "full30": "10702053",
			          "give30": "3210616",
			          "penalty30": "7491437",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    }
			  ]
			}
		*/
	})
}

func testSetPoolTier(t *testing.T) {
	t.Run("set pool tier", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		addPoolTier(t, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)
		std.TestSkipHeights(1)

		expected := `{"height":"130","time":"1234567925","gns":{"staker":"64212331","devOps":"24971457","communityPool":"7491437","govStaker":"0","protocolFee":"200000000","GnoswapAdmin":"99999803210616"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"2","numPoolSameTier":"1","position":[]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"127","stakedTimestamp":"1234567910","stakedDuration":"3","fullAmount":"18193490","ratio":"30","warmUpAmount":"5458047","full30":"18193490","give30":"5458047","penalty30":"12735443","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}`
		internalRewards := getPrintInfo(t)
		uassert.Equal(t, internalRewards, expected)
		/*
			{
			  "height": "130",
			  "time": "1234567925",
			  "gns": {
			    "staker": "64212331",
			    "devOps": "24971457",
			    "communityPool": "7491437",
			    "govStaker": "0",
			    "protocolFee": "200000000",
			    "GnoswapAdmin": "99999803210616"
			  },
			  "pool": [
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000",
			      "tier": "2",
			      "numPoolSameTier": "1",
			      "position": []
			    },
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			      "tier": "1",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "1",
			          "stakedHeight": "127",
			          "stakedTimestamp": "1234567910",
			          "stakedDuration": "3",
			          "fullAmount": "18193490",
			          "ratio": "30",
			          "warmUpAmount": "5458047",
			          "full30": "18193490",
			          "give30": "5458047",
			          "penalty30": "12735443",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    }
			  ]
			}
		*/
	})
}

func testStakeTokenPos02(t *testing.T) {
	t.Run("stake token 2", func(t *testing.T) {

		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)
		std.TestSkipHeights(10)

		expected := `{"height":"140","time":"1234567975","gns":{"staker":"171232876","devOps":"60644972","communityPool":"7491437","govStaker":"0","protocolFee":"200000000","GnoswapAdmin":"99999803210616"},"pool":[{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000","tier":"2","numPoolSameTier":"1","position":[{"lpTokenId":"2","stakedHeight":"130","stakedTimestamp":"1234567925","stakedDuration":"10","fullAmount":"0","ratio":"30","warmUpAmount":"0","full30":"0","give30":"0","penalty30":"0","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]},{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100","tier":"1","numPoolSameTier":"1","position":[{"lpTokenId":"1","stakedHeight":"127","stakedTimestamp":"1234567910","stakedDuration":"13","fullAmount":"93107860","ratio":"30","warmUpAmount":"27932358","full30":"93107860","give30":"27932358","penalty30":"65175502","full50":"0","give50":"0","penalty50":"0","full70":"0","give70":"0","penalty70":"0","full100":"0","give100":"0","penalty100":"0"}]}]}`
		internalRewards := getPrintInfo(t)
		uassert.Equal(t, internalRewards, expected)
		panic("fix position02 reward calculation (must have certain amount but 0 calculated)")
		/*
			{
			  "height": "140",
			  "time": "1234567975",
			  "gns": {
			    "staker": "171232876",
			    "devOps": "60644972",
			    "communityPool": "7491437",
			    "govStaker": "0",
			    "protocolFee": "200000000",
			    "GnoswapAdmin": "99999803210616"
			  },
			  "pool": [
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000",
			      "tier": "2",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "2",
			          "stakedHeight": "130",
			          "stakedTimestamp": "1234567925",
			          "stakedDuration": "10",
			          "fullAmount": "0",
			          "ratio": "30",
			          "warmUpAmount": "0",
			          "full30": "0",
			          "give30": "0",
			          "penalty30": "0",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    },
			    {
			      "poolPath": "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			      "tier": "1",
			      "numPoolSameTier": "1",
			      "position": [
			        {
			          "lpTokenId": "1",
			          "stakedHeight": "127",
			          "stakedTimestamp": "1234567910",
			          "stakedDuration": "13",
			          "fullAmount": "93107860",
			          "ratio": "30",
			          "warmUpAmount": "27932358",
			          "full30": "93107860",
			          "give30": "27932358",
			          "penalty30": "65175502",
			          "full50": "0",
			          "give50": "0",
			          "penalty50": "0",
			          "full70": "0",
			          "give70": "0",
			          "penalty70": "0",
			          "full100": "0",
			          "give100": "0",
			          "penalty100": "0"
			        }
			      ]
			    }
			  ]
			}
		*/
	})
}
