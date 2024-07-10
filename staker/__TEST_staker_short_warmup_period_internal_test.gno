package staker

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/consts"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/qux"

	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/gnft"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/qux:500"] = 1

	// tier 2
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 2

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
	// ---       event: {GNOSWAP gno.land/r/gnoswap/pool CreatePool [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/qux:500}]}

	pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337") // will be external
	// ---       event: {GNOSWAP gno.land/r/gnoswap/pool CreatePool [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100}]}

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
	// ---       event: {GNOSWAP gno.land/r/gnoswap/position Mint [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/qux:500} {p_tickLower 9000} {p_tickUpper 11000} {tokenId 1} {liquidity 1243732} {amount0 36790} {amount1 100000}]}
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
	// ---       event: {GNOSWAP gno.land/r/gnoswap/position Mint [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {p_tickLower -1000} {p_tickUpper 1000} {tokenId 2} {liquidity 2050516} {amount0 100000} {amount1 100000}]}
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
	// ---       event: {GNOSWAP gno.land/r/gnoswap/position Mint [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {p_tickLower -1000} {p_tickUpper 1000} {tokenId 3} {liquidity 2050516} {amount0 100000} {amount1 100000}]}
	std.TestSkipHeights(1)

	shouldEQ(t, tokenId, 3)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "100000")
	shouldEQ(t, amount1, "100000")
}

func TestStakeInternal_2(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(2))
	StakeToken(2)
	// ---       event: {GNOSWAP gno.land/r/gnoswap/staker StakeToken [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_tokenId 2} {poolPath gno.land/r/demo/bar:gno.land/r/demo/baz:100} {amount0 100000} {amount1 100000}]}

	std.TestSkipHeights(2)

	shouldEQ(t, gnft.OwnerOf(tid(2)), GetOrigPkgAddr())
	shouldEQ(t, len(deposits), 1)
}

func TestShortenWramUpPeriod(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnsOld := gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsOld, 99999800000000)

	std.TestSkipHeights(25) // skip certain block to start the warm-up period
	CollectReward(2)
	// full 100% => 256
	// due to wram up period 30% => 76.8
	gnsPrev := gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsPrev, 100000192105351)

	// no block skip
	// no change
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew := gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100000192105351)
	shouldEQ(t, gnsNew-gnsPrev, 0)

	// 1 block skip
	std.TestSkipHeights(1)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100000194510906)
	shouldEQ(t, gnsNew-gnsPrev, 2405555)

	// 1 block skip
	std.TestSkipHeights(1)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100000196916461)
	shouldEQ(t, gnsNew-gnsPrev, 2405555)

	// 1 block skip
	std.TestSkipHeights(1)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100000199322016)
	shouldEQ(t, gnsNew-gnsPrev, 2405555)

	std.TestSkipHeights(1)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100000201727571)
	shouldEQ(t, gnsNew-gnsPrev, 2405555)

	// NEXT TIER
	std.TestSkipHeights(1000)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100004210984738)
	shouldEQ(t, gnsNew-gnsPrev, 4009257167)

	std.TestSkipHeights(1)
	gnsPrev = gns.BalanceOf(a2u(gsa))
	CollectReward(2)
	gnsNew = gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gnsNew, 100004214993995)
	shouldEQ(t, gnsNew-gnsPrev, 4009257)
}
