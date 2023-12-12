package staker

import (
	"std"
	"testing"

	"encoding/gjson"

	"gno.land/p/demo/testutils"

	p "gno.land/r/pool"
	pos "gno.land/r/position"

	gnft "gno.land/r/gnft" // GNFT, Gnoswap NFT
	gns "gno.land/r/gns"   // GNS, Gnoswap Share
	obl "gno.land/r/obl"

	_ "gno.land/r/grc20_wrapper"
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02

	ira = testutils.TestAddress("ira") // Internal Reward Account
)

var (
	barPath = "gno.land/r/bar"
	quxPath = "gno.land/r/qux"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/bar:gno.land/r/qux:500"] = 1 // DEV

	// tier 2
	poolTiers["GNS/USDT_500"] = 2
	poolTiers["ATOM/GNS_500"] = 2

	// tier 3
	poolTiers["ATOM/GNOT_500"] = 3
	poolTiers["ATOM/USDT_500"] = 3
	poolTiers["ATOM/WETH_500"] = 3
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	p.InitManual()
	std.TestSkipHeights(1)

	p.CreatePool(barPath, quxPath, 500, 130621891405341611593710811006)
	std.TestSkipHeights(1)
}

func TestPositionMint(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := pos.Mint(
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
		shouldEQ(t, gnft.OwnerOf(tid(tPosTokenId)), GetOrigCaller()) // lp01

		// approve nft to staker
		std.TestSetPrevAddr(lp01)
		gnft.Approve(a2u(GetOrigPkgAddr()), tid(tPosTokenId))
		std.TestSkipHeights(1)
	}

	{
		std.TestSetOrigCaller(lp02)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := pos.Mint(
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
		shouldEQ(t, gnft.OwnerOf(tid(tPosTokenId)), GetOrigCaller()) // lp02

		// approve nft to staker
		std.TestSetPrevAddr(lp02)
		gnft.Approve(a2u(GetOrigPkgAddr()), tid(tPosTokenId))
		std.TestSkipHeights(1)
	}
}

func TestCreateExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)

	CreateExternalIncentive(
		"gno.land/r/bar:gno.land/r/qux:500", // targetPoolPath
		"gno.land/r/obl",                    // rewardToken
		10_000_000_000,                      // rewardAmount
		GetTimestamp(),                      // startTimestamp
		GetTimestamp()+TIMESTAMP_90DAYS,     // endTimestamp
	)
	CreateExternalIncentive("gno.land/r/bar:gno.land/r/qux:500", "gno.land/r/obl", 10_000_000_000, GetTimestamp(), GetTimestamp()+TIMESTAMP_90DAYS)
	std.TestSkipHeights(5)
}

func TestStakeToken(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		StakeToken(1) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(tid(1)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 1)
	}

	{
		std.TestSetOrigCaller(lp02)
		StakeToken(2) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(tid(2)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 2)
	}
}

func TestApiGetRewardsByAddress(t *testing.T) {
	{
		// lp01 reward check
		gra := ApiGetRewardByAddress(lp01)
		jsonStr := gjson.Parse(gra)
		shouldEQ(t, jsonStr.Get("response.data.0.type").String(), "Internal")
		shouldEQ(t, jsonStr.Get("response.data.0.token").String(), "GNS")
		shouldEQ(t, jsonStr.Get("response.data.0.reward").Int(), 126)
		shouldEQ(t, jsonStr.Get("response.data.1.type").String(), "External")
		shouldEQ(t, jsonStr.Get("response.data.1.token").String(), "gno.land/r/obl")
		shouldEQ(t, jsonStr.Get("response.data.1.reward").Int(), 648)
	}

	{
		// lp02 reward check
		gra := ApiGetRewardByAddress(lp02)
		jsonStr := gjson.Parse(gra)
		shouldEQ(t, jsonStr.Get("response.data.0.type").String(), "Internal")
		shouldEQ(t, jsonStr.Get("response.data.0.token").String(), "GNS")
		shouldEQ(t, jsonStr.Get("response.data.0.reward").Int(), 698)
		shouldEQ(t, jsonStr.Get("response.data.1.type").String(), "External")
		shouldEQ(t, jsonStr.Get("response.data.1.token").String(), "gno.land/r/obl")
		shouldEQ(t, jsonStr.Get("response.data.1.reward").Int(), 3595)
	}
}

func TestUnstakeToken(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		UnstakeToken(1) // GNFT tokenId
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(1)), lp01)

		// check reward
		shouldEQ(t, gns.BalanceOf(a2u(lp01)), 126) // internal
		shouldEQ(t, obl.BalanceOf(a2u(lp01)), 648) // external
	}

	{
		std.TestSetOrigCaller(lp02)
		UnstakeToken(2) // GNFT tokenId
		std.TestSkipHeights(1)

		shouldEQ(t, gnft.OwnerOf(tid(2)), lp02)

		// check reward
		shouldEQ(t, gns.BalanceOf(a2u(lp02)), 825)  // internal
		shouldEQ(t, obl.BalanceOf(a2u(lp02)), 4243) // external
	}
}

func TestEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)
	std.TestSkipHeights(9999999)
	EndExternalIncentive(GetOrigCaller().String(), "gno.land/r/bar:gno.land/r/qux:500", "gno.land/r/obl") // use same parameter as CreateExternalIncentive()
	std.TestSkipHeights(1)

	shouldEQ(t, len(incentives), 0)
	shouldEQ(t, len(poolIncentives["gno.land/r/bar:gno.land/r/qux:500"]), 0)
}

/* HELPERS */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
