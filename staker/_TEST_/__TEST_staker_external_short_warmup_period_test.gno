package staker

import (
	"std"
	"testing"

	"gno.land/r/demo/gnoswap/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"

	"gno.land/r/demo/gnft"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/qux:500"] = 1

	// tier 2
	// poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 2
	poolTiers["ATOM/GNS_500"] = 2

	// tier 3
	poolTiers["ATOM/GNOT_500"] = 3
	poolTiers["ATOM/USDT_500"] = 3
	poolTiers["ATOM/WETH_500"] = 3
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)
	std.TestSkipHeights(1)

	pl.CreatePool(barPath, quxPath, 500, "130621891405341611593710811006") // internal, tier 1 // tick 10_000 ≈ x2.7
	// ---       event: {GNOSWAP gno.land/r/demo/pool CreatePool [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/qux:500}]}

	pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337") // will be external
	// ---       event: {GNOSWAP gno.land/r/demo/pool CreatePool [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100}]}

	std.TestSkipHeights(3)
}

func TestMintBarQux500_1(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee500,       // fee
		int32(9000),  // tickLower
		int32(11000), // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
	// ---       event: {GNOSWAP gno.land/r/demo/position Mint [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/qux:500} {p_tickLower 9000} {p_tickUpper 11000} {tokenId 1} {liquidity 1243732} {amount0 36790} {amount1 100000}]}
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 1)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "36790")
	shouldEQ(t, amount1, "100000")
}

func TestMintBarBaz100_2(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		bazPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
	// ---       event: {GNOSWAP gno.land/r/demo/position Mint [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {p_tickLower -1000} {p_tickUpper 1000} {tokenId 2} {liquidity 2050516} {amount0 100000} {amount1 100000}]}
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 2)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "100000")
	shouldEQ(t, amount1, "100000")
}

func TestMintBarBaz100_3(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		bazPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
	// ---       event: {GNOSWAP gno.land/r/demo/position Mint [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {p_tickLower -1000} {p_tickUpper 1000} {tokenId 3} {liquidity 2050516} {amount0 100000} {amount1 100000}]}
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 3)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "100000")
	shouldEQ(t, amount1, "100000")
}

func TestCreateExternalIncentive(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	obl.Approve(a2u(consts.STAKER_ADDR), uint64(100_000_000))
	std.TestSkipHeights(1)

	AddToken(oblPath)
	CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // targetPoolPath
		"gno.land/r/demo/obl",                         // rewardToken
		"100000000",                                   // rewardAmount
		1234569600,                                    // startTimestamp
		1234569600+TIMESTAMP_90DAYS,                   // endTimestamp
	)
	// ---       event: {GNOSWAP gno.land/r/demo/staker CreateExternalIncentive [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {p_rewardToken gno.land/r/demo/obl} {p_rewardAmount 100000000} {p_startTimestamp 1234569600} {p_endTimestamp 1242345600}]}

	std.TestSkipHeights(1)
}

func TestStakeExternal_2(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(2))
	StakeToken(2)
	// ---       event: {GNOSWAP gno.land/r/demo/staker StakeToken [{m_callType DIRECT} {m_origCaller g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq} {m_prevRealm } {p_tokenId 2} {poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {amount0 100000} {amount1 100000}]}

	std.TestSkipHeights(2)

	shouldEQ(t, gnft.OwnerOf(tid(2)), GetOrigPkgAddr())
	shouldEQ(t, len(deposits), 1)
}

func TestShortenWramUpPeriod(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	oblOld := obl.BalanceOf(a2u(gsa))
	shouldEQ(t, oblOld, 99999900000000)

	{
		std.TestSkipHeights(25) // skip certain block to start the warm-up period
		CollectReward(2)
		// full 100% => 256
		// due to wram up period 30% => 76.8

		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900000076)
	}

	{
		// no block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900000076) // no change
	}

	{
		std.TestSkipHeights(1) // 1 block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900000095) // 19
	}

	{
		std.TestSkipHeights(1) // 1 block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900000114) // 19
	}

	{
		std.TestSkipHeights(1) // 1 block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900000133) // 19
	}

	{
		std.TestSkipHeights(100) // next tier!
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900003330)
	}

	{
		std.TestSkipHeights(1) // 1 block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900003362) // 32
	}

	{
		std.TestSkipHeights(1) // 1 block skip
		CollectReward(2)
		oblNew := obl.BalanceOf(a2u(gsa))
		shouldEQ(t, oblNew, 99999900003394) // 32
	}

}
