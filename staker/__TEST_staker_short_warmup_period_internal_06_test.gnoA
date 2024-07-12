// 1 pool for tier 1 ( + with 2 position)
// 1 pool for tier 1 ( + with 1 position)
// 1 pool for tier 3 ( + with 1 position)

package staker

import (
	"std"
	"testing"
	"time"

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
	poolTiers["gno.land/r/demo/bar:gno.land/r/demo/baz:100"] = InternalTier{
		tier:           2,
		startTimestamp: time.Now().Unix(),
	}

	// tier 3
	poolTiers["gno.land/r/demo/baz:gno.land/r/demo/qux:100"] = InternalTier{
		tier:           3,
		startTimestamp: time.Now().Unix(),
	}
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee()*3)

	pl.CreatePool(barPath, quxPath, 100, "79228162514264337593543950337")
	pl.CreatePool(barPath, bazPath, 100, "79228162514264337593543950337")
	pl.CreatePool(bazPath, quxPath, 100, "79228162514264337593543950337")
}

func TestMintBarQux100_Tier1_Pos1(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
}

func TestMintBarQux100_Tier1_Pos2(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
}

func TestMintBarBaz100_Tier2_Pos3(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		bazPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
}

func TestMintBarBaz100_Tier3_Pos4(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := pn.Mint(
		bazPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)
}

func TestStakeInternal_1_2_3_4(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(2))
	StakeToken(2)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(3))
	StakeToken(3)

	gnft.Approve(a2u(GetOrigPkgAddr()), tid(4))
	StakeToken(4)

	std.TestSkipHeights(2)
}

func TestShortenWramUpPeriodFirst(t *testing.T) {
	// SINGEL_BLOCK_GNS = 14269406 uGNS

	curr := getCurrentInfo()
	curr = printInfo(curr)
	/*
			***********************
		> height: 2
		> height inc by: 0
		> time: 1234567648
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 0
		> staker_chg		 0
		> dev ops		 0
		> dev ops_chg		 0
		> community pool_bal	 0
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 300000000
		> protocol fee_chg	 0
		> GSA_bal		 99999900000000
		> GSA_chg		 0

		GNS POSITION
	*/

	std.TestSetRealm(gsaRealm)

	std.TestSkipHeights(1)
	CollectReward(1)
	curr = printInfo(curr)
	/*
		EM_emissionGnsBalance 42808218
		(75%) mintedGnsAmount: 32106163
		***********************
		> height: 3
		> height inc by: 1
		> time: 1234567650
		> time inc by: 2

		GNS BALANCE CHANGE
		> staker_bal		 24079623
		> staker_chg		 24079623
		> dev ops		 8561643
		> dev ops_chg		 8561643
		> community pool_bal	 2140410
		> community pool_chg	 2140410
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 305620985
		> protocol fee_chg	 5620985
		> GSA_bal		 99999702405555
		> GSA_chg		 2405555

		GNS POSITION
		> tokenId: 1 amount: 0
		> tokenId: 2 amount: 8026540
		> tokenId: 3 amount: 9631848
		> tokenId: 4 amount: 6421232
	*/
}

func TestShortenWramUpPeriodNoChange(t *testing.T) {
	curr := getCurrentInfo()
	// no block skip
	// no change
	CollectReward(1)
	/*
		***********************
		> height: 3
		> height inc by: 0
		> time: 1234567650
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 24079623
		> staker_chg		 0
		> dev ops		 8561643
		> dev ops_chg		 0
		> community pool_bal	 2140410
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 305620985
		> protocol fee_chg	 0
		> GSA_bal		 99999702405555
		> GSA_chg		 0

		GNS POSITION
		> tokenId: 1 amount: 0
		> tokenId: 2 amount: 8026540
		> tokenId: 3 amount: 9631848
		> tokenId: 4 amount: 6421232
	*/

	curr = printInfo(curr)
}

func TestShortenWramUpPeriod5Block(t *testing.T) {
	curr := getCurrentInfo()
	// 5 block skip
	std.TestSkipHeights(5)
	CollectReward(1)
	/*
		EM_emissionGnsBalance 71347032
		(75%) mintedGnsAmount: 53510274
		***********************
		> height: 8
		> height inc by: 5
		> time: 1234567660
		> time inc by: 10

		GNS BALANCE CHANGE
		> staker_bal		 60199058
		> staker_chg		 36119435
		> dev ops		 		 22831049
		> dev ops_chg		 14269406
		> community pool_bal	 5707761
		> community pool_chg	 3567351
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 317799790
		> protocol fee_chg	 12178805
		> GSA_bal		 99999707617589
		> GSA_chg		 5212034

		GNS POSITION
		> tokenId: 1 amount: 0
		> tokenId: 2 amount: 17390839
		> tokenId: 3 amount: 25684930
		> tokenId: 4 amount: 17123286

		--- PASS: TestShortenWramUpPeriod5Block (0.01s)
		=== RUN   TestShortenWramUpPeriodSameBlockCollect02
	*/

	curr = printInfo(curr)
}

func TestShortenWramUpPeriodSameBlockCollect02(t *testing.T) {
	curr := getCurrentInfo()
	// smae block
	CollectReward(2)
	CollectReward(3)
	CollectReward(4)
	/*
		***********************
		> height: 8
		> height inc by: 0
		> time: 1234567660
		> time inc by: 0

		GNS BALANCE CHANGE
		> staker_bal		 3
		> staker_chg		 -60199055
		> dev ops		 22831049
		> dev ops_chg		 0
		> community pool_bal	 5707761
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 359957188
		> protocol fee_chg	 42157398
		> GSA_bal		 99999725659246
		> GSA_chg		 18041657

		GNS POSITION
		> tokenId: 1 amount: 0
		> tokenId: 2 amount: 0
		> tokenId: 3 amount: 0
		> tokenId: 4 amount: 0
	*/

	curr = printInfo(curr)
}
