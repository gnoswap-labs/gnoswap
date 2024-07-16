// 1 pool for tier 1
// 2 position

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
	std.TestSkipHeights(-122)
	if std.GetHeight() != 1 {
		panic("height should be 1")
	}

	// init pool tiers
	// tier 1
	// delete(poolTiers, MUST_EXISTS_IN_TIER_1)

	// poolTiers["gno.land/r/demo/bar:gno.land/r/demo/qux:100"] = InternalTier{
	// 	tier:           1,
	// 	startTimestamp: time.Now().Unix(),
	// 	startHeight:    std.GetHeight(),
	// 	updateHeight:   std.GetHeight(),
	// }

	// tier 2
	// poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"]

	// tier 3
	// poolTiers["gno.land/r/demo/baz:gno.land/r/demo/qux:100"] = 3
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

	pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
	pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337")
	// pl.CreatePool(bazPath, quxPath, 100, "79228162514264337593543950337")

	std.TestSkipHeights(1)
}

func TestMintBarQux100_1(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	shouldEQ(t, tokenId, 1)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa

	std.TestSkipHeights(1)
}

func TestMintBarBaz100_2(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		bazPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	shouldEQ(t, tokenId, 2)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa

	std.TestSkipHeights(1)
}

func TestCreateExternalIncentive(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	qux.Approve(a2u(consts.STAKER_ADDR), consts.UINT64_MAX)

	CreateExternalIncentive(
		"gno.land/r/demo/bar:gno.land/r/demo/qux:100", // targetPoolPath
		"gno.land/r/demo/qux",                         // rewardToken
		"100000000",                                   // rewardAmount
		1234569600,                                    // startTimestamp
		1234569600+TIMESTAMP_90DAYS,                   // endTimestamp
	)

	std.TestSkipHeights(1)
}

func TestStakeToken_1(t *testing.T) {
	std.TestSkipHeights(1000) // active external incentive

	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	std.TestSkipHeights(10)
}

func TestStartInternal(t *testing.T) {
	SetPoolTier("gno.land/r/demo/bar:gno.land/r/demo/qux:100", 1)

	std.TestSkipHeights(1)
}

func TestCollectReward0101(t *testing.T) {
	CollectReward(1)
	std.TestSkipHeights(1)
}

func TestCollectReward0102(t *testing.T) {
	std.TestSkipHeights(100)
	CollectReward(1)
	std.TestSkipHeights(1)
}
