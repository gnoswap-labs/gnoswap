package staker

import (
	"encoding/json"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	g "gno.land/r/gov"
	p "gno.land/r/pool"
	s "gno.land/r/position"

	gnft "gno.land/r/gnft" // GNFT, Gnoswap NFT
	gnos "gno.land/r/gnos" // GNOS, INTERNAL Reward Token
	obl "gno.land/r/obl"   // OBL, EXTERNAL Reward Token
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator
	ci01 = testutils.TestAddress("ci01") // Create Incentive Caller
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02

	ira = testutils.TestAddress("ira") // Internal Reward Account
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["BAR/FOO_500"] = 1 // DEV

	// tier 2
	poolTiers["GNOS/USDT_500"] = 2
	poolTiers["ATOM/GNOS_500"] = 2

	// tier 3
	poolTiers["ATOM/GNOT_500"] = 3
	poolTiers["ATOM/USDT_500"] = 3
	poolTiers["ATOM/WETH_500"] = 3

	// debug - print addr
	// println(pc01, "// pc01")
	// println(ci01, "// ci01")
	// println(lp01, "// lp01")
	// println(lp02, "// lp02")
	// println(ira, "// internal_reward_account")
	// println(p.GetOrigPkgAddr(), "// pool")
	// println(s.GetOrigPkgAddr(), "// position")
	// println(GetOrigPkgAddr(), "// staker")
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	p.InitManual()
	std.TestSkipHeights(1)
	p.CreatePool("foo", "bar", 500, 130621891405341611593710811006)
	std.TestSkipHeights(1)
}

func TestPositionMint(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := s.Mint(
			std.Address("foo"), // token0
			std.Address("bar"), // token1
			bigint(500),        // fee
			bigint(9000),       // tickLower
			bigint(11000),      // tickUpper
			bigint(1000),       // amount0Desired
			bigint(1000),       // amount1Desired
			bigint(1),          // amount0Min
			bigint(1),          // amount1Min
			bigint(2345678901), // deadline
		)
		std.TestSkipHeights(1)

		shouldEQ(t, tPosTokenId, bigint(1))
		shouldEQ(t, gnft.OwnerOf(bigint(1)), GetOrigCaller()) // lp01

		// approve nft to staker
		std.TestSetPrevAddr(lp01)
		gnft.Approve(a2u(GetOrigPkgAddr()), "1")
		std.TestSkipHeights(1)

		// mint liquidity: 12437
		// current pool liquidity: 12437
		// lp01 has 100%
	}

	{
		std.TestSetOrigCaller(lp02)
		tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := s.Mint(
			std.Address("foo"), // token0
			std.Address("bar"), // token1
			bigint(500),        // fee
			bigint(9100),       // tickLower
			bigint(12000),      // tickUpper
			bigint(5000),       // amount0Desired
			bigint(5000),       // amount1Desired
			bigint(1),          // amount0Min
			bigint(1),          // amount1Min
			bigint(2345678901), // deadline
		)
		std.TestSkipHeights(1)

		shouldEQ(t, tPosTokenId, bigint(2))
		shouldEQ(t, gnft.OwnerOf(bigint(2)), GetOrigCaller()) // lp02

		// approve nft to staker
		std.TestSetPrevAddr(lp02)
		gnft.Approve(a2u(GetOrigPkgAddr()), "2")
		std.TestSkipHeights(1)

		// mint liquidity: 68925
		// current pool liquidity: 81362
		// lp01 has 15.28%
		// lp02 has 84.72%
	}
}

func TestCreateExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)

	CreateExternalIncentive(
		"bar_foo_500",  // targetPoolPath
		"OBL",          // rewardToken
		10_000_000_000, // rewardAmount
		GetTimestamp(), // startTimestamp
		GetTimestamp()+TIMESTAMP_30DAYS+TIMESTAMP_30DAYS, // endTimestamp
	)
	std.TestSkipHeights(5)

	shouldPanic(t, func() {
		CreateExternalIncentive("bar_foo_500", "OBL", 10_000_000_000, GetTimestamp(), GetTimestamp()+TIMESTAMP_30DAYS+TIMESTAMP_30DAYS)
	})
}

func TestStakeToken(t *testing.T) {
	{
		std.TestSetOrigCaller(lp01)
		StakeToken(1) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(bigint(1)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 1)
	}

	{
		std.TestSetOrigCaller(lp02)
		StakeToken(2) // GNFT tokenId
		std.TestSkipHeights(2)

		shouldEQ(t, gnft.OwnerOf(bigint(2)), GetOrigPkgAddr()) // staker
		shouldEQ(t, len(deposits), 2)
	}

}

func TestApiGetRewardsByAddress(t *testing.T) {
	gra := ApiGetRewardByAddress(lp01)
	result := ResponseGetRewardByAddress{
		Stat: ApiQueryBase{
			Height:    0,
			Timestamp: 0,
		},
		Response: struct {
			Data []ApiRewardByAddress `json:"data"`
		}{
			Data: []ApiRewardByAddress{
				{
					Type:   "",
					Token:  "",
					Reward: 0,
				},
				{
					Type:   "",
					Token:  "",
					Reward: 0,
				},
			},
		},
	}

	if err := json.Unmarshal([]byte(gra), &result); err != nil {
		panic(err)
	}

	shouldEQ(t, result.Stat.Height, GetHeight())
	shouldEQ(t, result.Response.Data[0].Type, "Internal")
	shouldEQ(t, result.Response.Data[0].Token, "GNOS")
	shouldEQ(t, result.Response.Data[0].Reward, bigint(916))
	shouldEQ(t, result.Response.Data[1].Type, "External")
	shouldEQ(t, result.Response.Data[1].Token, "OBL")
	shouldEQ(t, result.Response.Data[1].Reward, bigint(1768))
}

func TestUnstakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	UnstakeToken(1) // GNFT tokenId
	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(bigint(1)), lp01) // lp01

	// check reward
	shouldEQ(t, gnos.BalanceOf(a2u(lp01)), bigint(916)) // internal
	shouldEQ(t, obl.BalanceOf(a2u(lp01)), bigint(1768)) // external
}

func TestEndExternalIncentive(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	std.TestSkipHeights(1036800)
	EndExternalIncentive("bar_foo_500", "OBL") // use same parameter as CreateExternalIncentive()
	std.TestSkipHeights(1)

	shouldEQ(t, len(incentives), 0)
	shouldEQ(t, len(poolIncentives["bar_foo_500"]), 0)
}

// GOV
func TestSubmitProposalParameterStakingReward(t *testing.T) {
	// Init GOV Contract
	g.Init()

	id := SubmitProposalParameterStakingReward(
		"staking reward change",  // title
		"change staking rewards", // summary
		"",                       // metadata
		0,                        // initialDeposit

		10, // newStakingReward1
		8,  // newStakingReward2
		6,  // newStakingReward3
		4,  // newStakingReward4
	)
	shouldEQ(t, id, uint64(1))
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
