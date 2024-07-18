package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/json"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/consts"
	"gno.land/r/gnoswap/gnft"
)

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
		startHeight:    std.GetHeight(),
		updateHeight:   std.GetHeight(),
	}

	// set pool create fee to 0 for testing
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	pl.SetPoolCreationFee(0)
}

func TestPoolCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	std.TestSkipHeights(1)

	pl.CreatePool(fooPath, barPath, uint32(500), "130621891405341611593710811006") // tick 10_000 ≈ x2.7

	pl.CreatePool(fooPath, barPath, uint32(100), "130621891405341611593710811006") // tick 10_000 ≈ x2.7

	std.TestSkipHeights(1)
}

func TestPositionMint01(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		fooPath,      // token0
		barPath,      // token1
		uint32(500),  // fee
		int32(9000),  // tickLower
		int32(11000), // tickUpper
		"1000",       // amount0Desired
		"1000",       // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,  // deadline
		gsa.String(),
	)

	std.TestSkipHeights(1)

	shouldEQ(t, lpTokenId, 1)
	shouldEQ(t, gnft.OwnerOf(tid(lpTokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "1000")
	shouldEQ(t, amount1, "368")

	// approve nft to staker for staking
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(lpTokenId))
	std.TestSkipHeights(1)
}

func TestPositionMint02(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		fooPath,      // token0
		barPath,      // token1
		uint32(500),  // fee
		int32(9100),  // tickLower
		int32(12000), // tickUpper
		"5000",       // amount0Desired
		"5000",       // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,  // deadline
		gsa.String(),
	)

	std.TestSkipHeights(1)

	shouldEQ(t, lpTokenId, 2)
	shouldEQ(t, gnft.OwnerOf(tid(lpTokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "5000")
	shouldEQ(t, amount1, "3979")

	// approve nft to staker
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(lpTokenId))
	std.TestSkipHeights(1)
}

func TestCreateExternalIncentiveFirst(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	obl.Approve(a2u(consts.STAKER_ADDR), 10_000_000_000)

	AddToken(oblPath)

	CreateExternalIncentive(
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", // targetPoolPath
		oblPath,                     // rewardToken
		"1000000000",                // rewardAmount
		1234569600,                  // startTimestamp
		1234569600+TIMESTAMP_90DAYS, // endTimestamp
	)
	shouldEQ(t, len(incentives), 1)

	incentiveId := incentiveIdCompute(gsa, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "gno.land/r/onbloc/obl", 1234569600, 1234569600+TIMESTAMP_90DAYS)
	shouldEQ(t, incentiveId, "ZzFsbXZycnJyNGVyMnVzODRoMjczMnNydTc2Yzl6bDJudmtuaGE4Yzpnbm8ubGFuZC9yL29uYmxvYy9iYXI6Z25vLmxhbmQvci9vbmJsb2MvZm9vOjUwMDpnbm8ubGFuZC9yL29uYmxvYy9vYmw6MTIzNDU2OTYwMDoxMjQyMzQ1NjAw")
	shouldEQ(t, incentives[incentiveId].rewardAmount.ToString(), "1000000000")
}

func TestCreateExternalIncentiveIncrease(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	obl.Approve(a2u(consts.STAKER_ADDR), 10_000_000_000)

	CreateExternalIncentive(
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", // targetPoolPath
		oblPath,                     // rewardToken
		"1000000000",                // rewardAmount
		1234569600,                  // startTimestamp
		1234569600+TIMESTAMP_90DAYS, // endTimestamp
	)

	shouldEQ(t, len(incentives), 1)

	incentiveId := incentiveIdCompute(gsa, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "gno.land/r/onbloc/obl", 1234569600, 1234569600+TIMESTAMP_90DAYS)
	shouldEQ(t, incentiveId, "ZzFsbXZycnJyNGVyMnVzODRoMjczMnNydTc2Yzl6bDJudmtuaGE4Yzpnbm8ubGFuZC9yL29uYmxvYy9iYXI6Z25vLmxhbmQvci9vbmJsb2MvZm9vOjUwMDpnbm8ubGFuZC9yL29uYmxvYy9vYmw6MTIzNDU2OTYwMDoxMjQyMzQ1NjAw")
	shouldEQ(t, incentives[incentiveId].rewardAmount.ToString(), "2000000000")

	std.TestSkipHeights(1)
}

func TestStakeToken01(t *testing.T) {
	std.TestSkipHeights(1000) // active

	std.TestSetRealm(gsaRealm)
	StakeToken(1) // GNFT tokenId

	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(tid(1)), GetOrigPkgAddr()) // staker
	shouldEQ(t, len(deposits), 1)
}

func TestStakeToken02(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	StakeToken(2) // GNFT tokenId

	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(tid(2)), GetOrigPkgAddr()) // staker
	shouldEQ(t, len(deposits), 2)
}

func TestApiGetStakes(t *testing.T) {
	gss := ApiGetStakes()

	root, err := json.Unmarshal([]byte(gss))
	if err != nil {
		panic(err)
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err)
	}

	shouldEQ(t, response.Size(), 2)
}

func TestApiGetRewardTokens(t *testing.T) {
	grt := ApiGetRewardTokens()

	root, err := json.Unmarshal([]byte(grt))
	if err != nil {
		panic(err)
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err)
	}

	shouldEQ(t, response.Size(), 1)
}

func TestUnstakeToken01(t *testing.T) {
	std.TestSkipHeights(350)

	std.TestSetRealm(gsaRealm)
	UnstakeToken(1) // GNFT tokenId

	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(tid(1)), gsa)

	// check reward
	shouldEQ(t, gns.BalanceOf(a2u(gsa)), 100000128643323) // internal
	shouldEQ(t, obl.BalanceOf(a2u(gsa)), 99998000019757)  // external
}

func TestUnstakeToken02(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	UnstakeToken(2) // GNFT tokenId

	std.TestSkipHeights(1)

	shouldEQ(t, gnft.OwnerOf(tid(2)), gsa)

	// check reward
	shouldEQ(t, gns.BalanceOf(a2u(gsa)), 100000830885278) // internal
	shouldEQ(t, obl.BalanceOf(a2u(gsa)), 99998000149262)  // external
}

func TestCreateExternalIncentiveSecond(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.STAKER_ADDR), 10_000_000_000)

	CreateExternalIncentive(
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", // targetPoolPath
		barPath,                     // rewardToken
		"1000000000",                // rewardAmount
		1234656000,                  // startTimestamp
		1234656000+TIMESTAMP_90DAYS, // endTimestamp
	)
	shouldEQ(t, len(incentives), 2)
}

func TestEndExternalIncentive(t *testing.T) {
	shouldEQ(t, len(incentives), 2)

	std.TestSetOrigCaller(gsa)

	// incentive time isn't over yet
	shouldPanicWithMsg(t, func() {
		EndExternalIncentive(gsa.String(), "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "gno.land/r/onbloc/obl", 1234569600, 1234569600+TIMESTAMP_90DAYS)
	}, "[STAKER] staker.gno__EndExternalIncentive() || cannot end incentive before endTimestamp(1242345600), current(1234570620)")

	std.TestSkipHeights(9999999)
	EndExternalIncentive(gsa.String(), "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "gno.land/r/onbloc/obl", 1234569600, 1234569600+TIMESTAMP_90DAYS) // use same parameter as CreateExternalIncentive()

	shouldEQ(t, len(incentives), 1) // other pool left

	shouldEQ(t, len(poolIncentives["gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"]), 1) // internal left for this pool
}
