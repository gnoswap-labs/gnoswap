package staker

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/gnoswap/v1/gnft"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	poolPath string = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func TestMore04(t *testing.T) {
	testInit(t)
	testCreatePool(t)
	testMintBarBaz100Pos01(t)
	testMintBarBaz100Pos02(t)
	testMintBarBaz100Pos03(t)
	testMintBarBaz100Pos04(t)
	testMintBarBaz100Pos05(t)
	testPrintWarmup(t)
	testStakeTokenPos01(t)
	testStakeTokenPos02ToWarmUp70_Pos03ToWarmUp50_Pos04ToWarmUp30_Pos05(t)
}

func testInit(t *testing.T) {
	t.Run("initialize", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// bar:baz:100 is only pool for internal emission reward (tier1)
		deletePoolTier(t, MUST_EXISTS_IN_TIER_1)
		addPoolTier(t, poolPath, 1)

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

func testCreatePool(t *testing.T) {
	t.Run("create pool", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337") // price ratio 1:1
		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100Pos01(t *testing.T) {
	t.Run("mint position 01, bar:baz:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,         // token0
			bazPath,         // token1
			fee100,          // fee
			consts.MIN_TICK, // tickLower
			consts.MAX_TICK, // tickUpper
			"3000",          // amount0Desired
			"3000",          // amount1Desired
			"1",             // amount0Min
			"1",             // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100Pos02(t *testing.T) {
	t.Run("mint position 02, bar:baz:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,      // token0
			bazPath,      // token1
			fee100,       // fee
			int32(-6931), // tickLower ( price ratio 1:0.5 )
			int32(6932),  // tickUpper ( price ratio 1:2)
			"6000",       // amount0Desired
			"6000",       // amount1Desired
			"1",          // amount0Min
			"1",          // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100Pos03(t *testing.T) {
	t.Run("mint position 03, bar:baz:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,     // token0
			bazPath,     // token1
			fee100,      // fee
			int32(-944), // tickLower ( price ratio 1:0.9 )
			int32(954),  // tickUpper ( price ratio 1:1.1 )
			"1000",      // amount0Desired
			"1000",      // amount1Desired
			"1",         // amount0Min
			"1",         // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100Pos04(t *testing.T) {
	t.Run("mint position 04, bar:baz:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,     // token0
			bazPath,     // token1
			fee100,      // fee
			int32(-944), // tickLower ( price ratio 1:0.90 )
			int32(-512), // tickUpper ( price ratio 1:0.95 )
			"50",        // amount0Desired
			"50",        // amount1Desired
			"0",         // amount0Min
			"0",         // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)
	})
}

func testMintBarBaz100Pos05(t *testing.T) {
	t.Run("mint position 05, bar:baz:100", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		tokenId, liquidity, amount0, amount1 := pn.Mint(
			barPath,                   // token0
			bazPath,                   // token1
			fee100,                    // fee
			int32(consts.MAX_TICK-10), // tickLower
			int32(consts.MAX_TICK),    // tickUpper
			"50",                      // amount0Desired
			"50",                      // amount1Desired
			"0",                       // amount0Min
			"0",                       // amount1Min
			max_timeout,
			adminAddr,
			adminAddr,
		)
		std.TestSkipHeights(1)
	})
}

func testPrintWarmup(t *testing.T) {
	t.Run("print warmup", func(t *testing.T) {
		println("30", warmupTemplate[0].BlockDuration)
		println("50", warmupTemplate[1].BlockDuration)
		println("70", warmupTemplate[2].BlockDuration)
		println("100", warmupTemplate[3].BlockDuration)
	})
}

func testStakeTokenPos01(t *testing.T) {
	t.Run("stake position 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(1))
		StakeToken(1)

		// make it warm up 100%
		std.TestSkipHeights(1944001) // 	// 1+216000+432000+1296000
	})
}

func testStakeTokenPos02ToWarmUp70_Pos03ToWarmUp50_Pos04ToWarmUp30_Pos05(t *testing.T) {
	t.Run("stake position 02", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(2))
		StakeToken(2)
		std.TestSkipHeights(432001) // 70%
	})

	t.Run("stake position 03", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(3))
		StakeToken(3)
		std.TestSkipHeights(216001) //  50%
	})

	t.Run("stake position 04", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(4))
		StakeToken(4)          //  (out of range, will become in-range by swap)
		std.TestSkipHeights(1) // 30%
	})

	t.Run("stake position 05", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gnft.Approve(consts.STAKER_ADDR, tid(5))
		StakeToken(5)          //  (out of range forever)
		std.TestSkipHeights(1) // 30%
	})

	t.Run("collect reward for all positions_01_to_05", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		CollectReward(1, false) // toUser 13458934078339
		CollectReward(2, false) // toUser 2139767397225
		CollectReward(4, false) // toUser 0 (out of range)
		CollectReward(5, false) // toUser 0 (out of range)

		// FIXED: staker.gno CollectReward (L405~L419)
		CollectReward(3, false)
	})
}
