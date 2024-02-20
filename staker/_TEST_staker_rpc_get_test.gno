package staker

import (
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/gnft"
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

var poolPath = "gno.land/r/demo/bar:gno.land/r/demo/qux:500"
var incentiveId = "ZzFqZzhtdHV0dTlraGhmd2M0bnhtdWhjcGZ0ZjBwYWpkaGZ2c3FmNTpnbm8ubGFuZC9yL2RlbW8vYmFyOmduby5sYW5kL3IvZGVtby9xdXg6NTAwOmduby5sYW5kL3IvZGVtby9vYmw="
var lpTokenId = uint64(1)

func TestStakerPoolIncentives(t *testing.T) {
	incentives := StakerPoolIncentives(poolPath)
	shouldEQ(t, incentives[0], incentiveId)
}

func TestStakerIncentiveTargetPoolPath(t *testing.T) {
	targetPoolPath := StakerIncentiveTargetPoolPath(incentiveId)
	shouldEQ(t, targetPoolPath, poolPath)
}

func TestStakerIncentiveRewardToken(t *testing.T) {
	rewardToken := StakerIncentiveRewardToken(incentiveId)
	shouldEQ(t, rewardToken, "gno.land/r/demo/obl")
}

func TestStakerIncentiveRewardAmount(t *testing.T) {
	rewardAmount := StakerIncentiveRewardAmount(incentiveId)
	shouldEQ(t, rewardAmount, bigint(20_000_000_000))
}

func TestStakerIncentiveStartTimestamp(t *testing.T) {
	startTimestamp := StakerIncentiveStartTimestamp(incentiveId)
	shouldEQ(t, startTimestamp, 1234567920)
}

func TestStakerIncentiveEndTimestamp(t *testing.T) {
	endTimestamp := StakerIncentiveEndTimestamp(incentiveId)
	shouldEQ(t, endTimestamp, 1242343920)
}

func TestStakerIncentiveRefundee(t *testing.T) {
	refundee := StakerIncentiveRefundee(incentiveId)
	shouldEQ(t, refundee, a2u(test1))
}

func TestStakerDepositOwner(t *testing.T) {
	owner := StakerDepositOwner(lpTokenId)
	shouldEQ(t, owner, a2u(test1))
}

func TestStakerDepositNumberOfStakes(t *testing.T) {
	numberOfStakes := StakerDepositNumberOfStakes(lpTokenId)
	shouldEQ(t, numberOfStakes, 1)
}

func TestStakerDepositStakeTimestamp(t *testing.T) {
	stakeTimestamp := StakerDepositStakeTimestamp(lpTokenId)
	shouldEQ(t, stakeTimestamp, 1234567945)
}

func TestStakerDepositTargetPoolPath(t *testing.T) {
	targetPoolPath := StakerDepositTargetPoolPath(lpTokenId)
	shouldEQ(t, targetPoolPath, poolPath)
}

func TestStakerPoolTier(t *testing.T) {
	tier := StakerPoolTier(poolPath)
	shouldEQ(t, tier, 1)
}
