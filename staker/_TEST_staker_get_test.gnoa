package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	gnft "gno.land/r/gnft" // GNFT, Gnoswap NFT
	p "gno.land/r/pool"
	pos "gno.land/r/position"

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
	fooPath = "gno.land/r/foo"
	barPath = "gno.land/r/bar"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	p.InitManual()
	std.TestSkipHeights(1)

	p.CreatePool(fooPath, barPath, 500, 130621891405341611593710811006)
	std.TestSkipHeights(1)
}

func TestPositionMint(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := pos.Mint(
			fooPath,            // token0
			barPath,            // token1
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
			fooPath,            // token0
			barPath,            // token1
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
		"gno.land/r/bar:gno.land/r/foo:500", // targetPoolPath
		"gno.land/r/obl",                    // rewardToken
		10_000_000_000,                      // rewardAmount
		GetTimestamp(),                      // startTimestamp
		GetTimestamp()+TIMESTAMP_90DAYS,     // endTimestamp
	)
	std.TestSkipHeights(5)

	shouldPanic(t, func() {
		CreateExternalIncentive("gno.land/r/bar:gno.land/r/foo:500", "OBL", 10_000_000_000, GetTimestamp(), GetTimestamp()+TIMESTAMP_90DAYS)
	})
}

func TestStakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	StakeToken(1)

	// don't stake
	// std.TestSetOrigCaller(lp02)
	// StakeToken(2)
}

func TestisStaked(t *testing.T) {
	shouldEQ(t, IsStaked(1), true)
	shouldEQ(t, IsStaked(2), false)
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
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
