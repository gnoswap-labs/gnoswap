package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/consts"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

func init() {
	// init pool tiers
	// tier 1
	delete(poolTiers, MUST_EXISTS_IN_TIER_1)

	poolTiers["gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
		startHeight:    std.GetHeight(),
		updateHeight:   std.GetHeight(),
	}

	// tier 2
	// poolTiers["gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"]

	// tier 3
	// poolTiers["gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:100"] = 3

	std.TestSkipHeights(1)
}

func TestDoulbeMint(t *testing.T) {
	en.MintAndDistributeGns()
	en.MintAndDistributeGns()

	std.TestSkipHeights(1)
}

func TestPoolInitCreatePool(t *testing.T) {

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

	pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
	pl.CreatePool(barPath, bazPath, 3000, "79228162514264337593543950337")

	std.TestSkipHeights(1)
}

func TestMintBarQux100_1(t *testing.T) {
	curr := getCurrentInfo()

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

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(1)
}

func TestMintBarBaz100_2(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		bazPath,      // token1
		fee3000,      // fee
		int32(-1020), // tickLower
		int32(1020),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	shouldEQ(t, tokenId, 2)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(1)
}

func TestStakeToken_1(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(1)
}

func TestSetPoolTier(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSkipHeights(800) // this reward should go to bar:qux:100

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	SetPoolTier("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(1)
}

func TestStakeToken_2(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(2))
	StakeToken(2)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(1)
}

func TestCollect1_1(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(1)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(5)
}

func TestCollect1_2(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(1)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(500)
}

func TestCollect1_3(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(1)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(50)
}

func TestCollect1_4(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(1)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(50)
}

func TestCollect2_1(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(2)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(5)
}

func TestCollectAll_1(t *testing.T) {
	curr := getCurrentInfo()

	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	CollectReward(1)
	CollectReward(2)

	println(GetPrintInfo())
	println()
	printInfo(curr)

	std.TestSkipHeights(5)
}

func TestJustPrint(t *testing.T) {
	curr := getCurrentInfo()

	println(GetPrintInfo())
	println()
	printInfo(curr)
}
