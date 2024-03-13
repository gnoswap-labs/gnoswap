package staker

import (
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/gnft"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/qux"

	"gno.land/r/demo/consts"
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
	std.TestSetPrevAddr(gsa)
	pl.InitManual()
	std.TestSkipHeights(1)

	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)
	std.TestSkipHeights(1)

	pl.CreatePool(barPath, quxPath, 500, "130621891405341611593710811006") // tick 10_000 ≈ x2.7
	std.TestSkipHeights(1)
}

func TestMintAndStake(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)

	lpTokenId, liquidity, amount0, amount1, poolPath := MintAndStake(
		barPath,      // token0
		quxPath,      // token1
		fee500,       // fee
		int32(9000),  // tickLower
		int32(11000), // tickUpper
		"1000",       // amount0Desired
		"1000",       // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
	)
	std.TestSkipHeights(1)
}

func TestPositionCollectFee(t *testing.T) {
	std.TestSetPrevAddr(test1)
	pn.CollectFee(1) // lpTokenId
	std.TestSkipHeights(1)
}

func TestCollectReward(t *testing.T) {
	// internal reward distribution
	std.TestSetPrevAddr(consts.INTERNAL_REWARD_ACCOUNT)
	gns.Approve(a2u(consts.STAKER_ADDR), consts.UINT64_MAX)

	std.TestSetPrevAddr(test1)
	CollectReward(1) // lpTokenId
	std.TestSkipHeights(1)
}

func TestUnstakeToken(t *testing.T) {
	ownerOfLp1 := gnft.OwnerOf(tid(1))
	shouldEQ(t, ownerOfLp1, a2u(consts.STAKER_ADDR))

	std.TestSetPrevAddr(test1)
	UnstakeToken(1) // lpTokenId
	std.TestSkipHeights(1)

	ownerOfLp1 = gnft.OwnerOf(tid(1))
	shouldEQ(t, ownerOfLp1, a2u(test1))
}
