// 1 pool for tier 1
// 2 position

package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/consts"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/qux"

	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/gnft"
)

func init() {
	// init pool tiers
	// tier 1
	delete(poolTiers, MUST_EXISTS_IN_TIER_1)
	std.TestSkipHeights(-123)
	if std.GetHeight() != 0 {
		panic("height should be 0")
	}
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/qux:100"] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
	}

	// tier 2
	// poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = 2

	// tier 3
	// poolTiers["gno.land/r/demo/baz:gno.land/r/demo/qux:100"] = 3
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

	pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
	// pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337")
	// pl.CreatePool(bazPath, quxPath, 100, "79228162514264337593543950337")

	std.TestSkipHeights(1)
}

func TestMintBarQux100_1(t *testing.T) {
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

func TestStakeInternal_1(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	std.TestSkipHeights(1)
}

func TestShortenWramUpPeriodFirst(t *testing.T) {
	// SINGEL_BLOCK_GNS = 14269406 uGNS

	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)

	std.TestSkipHeights(1)
}

func TestFunc11(t *testing.T) {
	en.MintAndDistributeGns()
	CalcPoolPosition()
	println(GetPrintInfo())

	std.TestSkipHeights(1)
}

func TestFunc12(t *testing.T) {
	std.TestSkipHeights(50)
	en.MintAndDistributeGns()
	CalcPoolPosition()
	println(GetPrintInfo())

}

func TestFunc13CollectReward(t *testing.T) {
	std.TestSkipHeights(1)

	CollectReward(1)
	// println()
	// println()
	// println(GetPrintInfo())
}
