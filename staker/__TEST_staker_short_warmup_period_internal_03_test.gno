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
}

func TestMintBarQux100_2(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1200), // tickLower
		int32(1200),  // tickUpper
		"70000000",   // amount0Desired
		"70000000",   // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	shouldEQ(t, tokenId, 2)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
}

func TestMintBarQux100_3(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1200), // tickLower
		int32(1200),  // tickUpper
		"70000",      // amount0Desired
		"70000",      // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	std.TestSkipHeights(1)
}

func TestStakeInternal_1_2_3(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(2))
	StakeToken(2)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(3))
	StakeToken(3)

	std.TestSkipHeights(1)
}

func TestShortenWramUpPeriodFirst(t *testing.T) {
	// SINGEL_BLOCK_GNS = 14269406 uGNS

	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)

	/*
		POOL_LIQUIDITY		1203278059
		Token1 LIQUIDITY	1025					  0.000085184
		Token2 LIQUIDITY	1202074960		99.9000148809
		Token3 LIQUIDITY 	1202074				 0.0998999351

		GNS REWARD 			10702054
		Token1 REWARD 	9
		Tokne2 REWARD		10691353
		Token3 REWARD  	10691


		//
		EM_emissionGnsBalance: 14269406
		75% // mintedGnsAmount 10702054
		poolLastTmpGns[poolPath]: 0
		***********************
		> height: 1
		> height inc by: 0
		> time: 1234567646
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 10702054
		> staker_chg		 0
		> dev ops		 2853881
		> dev ops_chg		 0
		> community pool_bal	 713470
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 100000000
		> protocol fee_chg	 0
		> GSA_bal		 99999900000000
		> GSA_chg		 0

		GNS POSITION
		> tokenId: 1 amount: 9
		> tokenId: 2 amount: 10691353
		> tokenId: 3 amount: 10691
	*/

	std.TestSkipHeights(1)
	println()
	println()
	println()

}

func TestShortenWramUpPeriod1Block(t *testing.T) {
	// SINGEL_BLOCK_GNS = 14269406 uGNS

	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)

	/*
		POOL_LIQUIDITY		1203278059
		Token1 LIQUIDITY	1025					  0.000085184
		Token2 LIQUIDITY	1202074960		99.9000148809
		Token3 LIQUIDITY 	1202074				 0.0998999351

		GNS REWARD 			10702054
		Token1 REWARD 	9
		Tokne2 REWARD		10691353
		Token3 REWARD  	10691
	*/
	/*
		EM_emissionGnsBalance: 14269407
		75% // mintedGnsAmount 10702055
		***********************
		> height: 2
		> height inc by: 0
		> time: 1234567648
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 21404109
		> staker_chg		 0
		> dev ops		 5707762
		> dev ops_chg		 0
		> community pool_bal	 1426940
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 100000000
		> protocol fee_chg	 0
		> GSA_bal		 99999900000000
		> GSA_chg		 0

		GNS POSITION
		> tokenId: 1 amount: map{(30 uint64):(18 uint64)}
		> tokenId: 2 amount: map{(30 uint64):(21382708 uint64)}
		> tokenId: 3 amount: map{(30 uint64):(21382 uint64)}
	*/
	println()
	println()
	println()

}

func TestShortenWramUpPeriod150Block(t *testing.T) {
	std.TestSkipHeights(160)

	// SINGEL_BLOCK_GNS = 14269406 uGNS

	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)

	/*
		POOL_LIQUIDITY		1203278059
		Token1 LIQUIDITY	1025					  0.000085184
		Token2 LIQUIDITY	1202074960		99.9000148809
		Token3 LIQUIDITY 	1202074				 0.0998999351

		GNS REWARD 			10702054
		Token1 REWARD 	9
		Tokne2 REWARD		10691353
		Token3 REWARD  	10691
	*/
	/*
		EM_emissionGnsBalance: 14269407
		75% // mintedGnsAmount 10702055
		***********************
		> height: 2
		> height inc by: 0
		> time: 1234567648
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 21404109
		> staker_chg		 0
		> dev ops		 5707762
		> dev ops_chg		 0
		> community pool_bal	 1426940
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 100000000
		> protocol fee_chg	 0
		> GSA_bal		 99999900000000
		> GSA_chg		 0

		GNS POSITION
		> tokenId: 1 amount: map{(30 uint64):(18 uint64)}
		> tokenId: 2 amount: map{(30 uint64):(21382708 uint64)}
		> tokenId: 3 amount: map{(30 uint64):(21382 uint64)}
	*/
	println()
	println()
	println()

}

func TestCollectReward(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	CollectReward(1)
	CollectReward(2)
	CollectReward(3)

	curr := getCurrentInfo()
	curr = printInfo(curr)
	println()

	println("><><><><><> SAME BLOCK REWARDING")

	CollectReward(1)
	CollectReward(2)
	CollectReward(3)

	println("><><><><><> SAME BLOCK REWARDING END")
	std.TestSkipHeights(1)
}

func TestLast(t *testing.T) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)

	std.TestSkipHeights(1)
}

func TestCollectReward1Block(t *testing.T) {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	curr := getCurrentInfo()
	curr = printInfo(curr)
	println()

	std.TestSetRealm(gsaRealm)
	CollectReward(1)
	CollectReward(2)
	CollectReward(3)

	std.TestSkipHeights(1)

	println()
	println()
	println()
	println()
	println(GetPrintInfo())
}

func TestFinalCollect(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	CollectReward(1)
	CollectReward(2)
	CollectReward(3)

	std.TestSkipHeights(1)
}
