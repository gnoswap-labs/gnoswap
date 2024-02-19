package staker

import (
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"

	"gno.land/r/demo/obl"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/qux:500"] = 1 // DEV

	// tier 2
	poolTiers["GNS/USDT_500"] = 2
	poolTiers["ATOM/GNS_500"] = 2

	// tier 3
	poolTiers["ATOM/GNOT_500"] = 3
	poolTiers["ATOM/USDT_500"] = 3
	poolTiers["ATOM/WETH_500"] = 3
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)

	pl.CreatePool(barPath, quxPath, 500, 130621891405341611593710811006)
	std.TestSkipHeights(1)
}

func TestPositionMint(t *testing.T) {
	{
		std.TestSetOrigCaller(test1)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := pn.Mint(
			barPath,            // token0
			quxPath,            // token1
			uint16(500),        // fee
			int32(9000),        // tickLower
			int32(11000),       // tickUpper
			bigint(1000),       // amount0Desired
			bigint(1000),       // amount1Desired
			bigint(1),          // amount0Min
			bigint(1),          // amount1Min
			bigint(2345678901), // deadline
		)
		std.TestSkipHeights(1)

		shouldEQ(t, tPosTokenId, 1)
		shouldEQ(t, gnft.OwnerOf(tid(tPosTokenId)), GetOrigCaller()) // test1

		// approve nft to staker
		std.TestSetPrevAddr(test1)
		gnft.Approve(a2u(GetOrigPkgAddr()), tid(tPosTokenId))
		std.TestSkipHeights(1)
	}

	{
		std.TestSetOrigCaller(test1)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := pn.Mint(
			barPath,            // token0
			quxPath,            // token1
			uint16(500),        // fee
			int32(9100),        // tickLower
			int32(12000),       // tickUpper
			bigint(5000),       // amount0Desired
			bigint(5000),       // amount1Desired
			bigint(1),          // amount0Min
			bigint(1),          // amount1Min
			bigint(2345678901), // deadline
		)
		std.TestSkipHeights(1)

		shouldEQ(t, tPosTokenId, 2)
		shouldEQ(t, gnft.OwnerOf(tid(tPosTokenId)), GetOrigCaller()) // test1

		// approve nft to staker
		std.TestSetPrevAddr(test1)
		gnft.Approve(a2u(GetOrigPkgAddr()), tid(tPosTokenId))
		std.TestSkipHeights(1)
	}
}

func TestCreateExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(test1)

	CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/qux:500", // targetPoolPath
		"gno.land/r/demo/obl",                         // rewardToken
		10_000_000_000,                                // rewardAmount
		GetTimestamp(),                                // startTimestamp
		GetTimestamp()+TIMESTAMP_90DAYS,               // endTimestamp
	)
	CreateExternalIncentive("gno.land/r/demo/bar:gno.land/r/demo/qux:500", "gno.land/r/demo/obl", 10_000_000_000, GetTimestamp(), GetTimestamp()+TIMESTAMP_90DAYS)
	std.TestSkipHeights(5)
}

func TestStakeToken(t *testing.T) {
	{
		std.TestSetOrigCaller(test1)
		StakeToken(1) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(tid(1)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 1)
	}

	{
		std.TestSetOrigCaller(test1)
		StakeToken(2) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(tid(2)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 2)
	}
}

func TestCollectReward(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// before claim
	gnsOld := gns.BalanceOf(a2u(test1))
	shouldEQ(t, gnsOld, 99999999500)

	CollectReward(1) // GNFT tokenId
	gnsNew := gns.BalanceOf(a2u(test1))
	shouldEQ(t, gnsNew, 99999999626)

}

func TestUnstakeToken(t *testing.T) {
	{
		std.TestSetOrigCaller(test1)
		UnstakeToken(1) // GNFT tokenId
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(1)), test1)

		// check reward
		shouldEQ(t, gns.BalanceOf(a2u(test1)), 99999999626)     // internal
		shouldEQ(t, obl.BalanceOf(a2u(test1)), 499980000000648) // external
	}

	{
		std.TestSetOrigCaller(test1)
		UnstakeToken(2) // GNFT tokenId
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(2)), test1)

		// check reward
		shouldEQ(t, gns.BalanceOf(a2u(test1)), 100000000451)    // internal
		shouldEQ(t, obl.BalanceOf(a2u(test1)), 499980000004891) // external
	}
}

func TestEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(test1)
	std.TestSkipHeights(9999999)
	EndExternalIncentive(GetOrigCaller().String(), "gno.land/r/demo/bar:gno.land/r/demo/qux:500", "gno.land/r/demo/obl") // use same parameter as CreateExternalIncentive()
	std.TestSkipHeights(1)

	shouldEQ(t, len(incentives), 0)
	shouldEQ(t, len(poolIncentives["gno.land/r/demo/bar:gno.land/r/demo/qux:500"]), 0)
}