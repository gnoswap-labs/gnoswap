// 1 pool for tier 1
// 1 position

package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/consts"

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
	372026958
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
		"100000",     // amount0Desired
		"100000",     // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		gsa.String(),
	)

	shouldEQ(t, tokenId, 1)
	shouldEQ(t, gnft.OwnerOf(tid(tokenId)), std.GetOrigCaller()) // gsa
	shouldEQ(t, amount0, "100000")
	shouldEQ(t, amount1, "100000")
}

func TestStakeInternal_1(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(1))
	StakeToken(1)

	std.TestSkipHeights(2)

	shouldEQ(t, gnft.OwnerOf(tid(1)), GetOrigPkgAddr())
	shouldEQ(t, len(deposits), 1)
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
		> staker_bal 0
		> staker_chg		 0
		> dev ops		 0
		> dev ops_chg		 0
		> community pool_bal	 0
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 100000000
		> protocol fee_chg	 0
		> GSA_bal		 99999900000000
		> GSA_chg		 0
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
		> staker_bal		 0
		> staker_chg		 0
		> dev ops		 8561643
		> dev ops_chg		 8561643
		> community pool_bal	 2140410
		> community pool_chg	 2140410
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 122483946
		> protocol fee_chg	 22483946
		> GSA_bal		 99999909622217
		> GSA_chg		 9622217

		GNS POSITION
		> tokenId: 1 amount: 0
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
		> staker_bal		 0
		> staker_chg		 0
		> dev ops		 8561643
		> dev ops_chg		 0
		> community pool_bal	 2140410
		> community pool_chg	 0
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 122483946
		> protocol fee_chg	 0
		> GSA_bal		 99999909622217
		> GSA_chg		 0

		GNS POSITION
		> tokenId: 1 amount: 0
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
		> staker_bal		 0
		> staker_chg		 0
		> dev ops		 22831049
		> dev ops_chg		 14269406
		> community pool_bal	 5707761
		> community pool_chg	 3567351
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 159957191
		> protocol fee_chg	 37473245
		> GSA_bal		 99999925659246
		> GSA_chg		 16037029

		GNS POSITION
		> tokenId: 1 amount: 0
	*/

	curr = printInfo(curr)
}

func TestShortenWramUpPeriodLARGEBlock(t *testing.T) {
	println()
	println()

	curr := getCurrentInfo()
	std.TestSkipHeights(1000)
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
		> staker_bal		 0
		> staker_chg		 0
		> dev ops		 22831049
		> dev ops_chg		 14269406
		> community pool_bal	 5707761
		> community pool_chg	 3567351
		> x_gns_bal		 0
		> x_gns_chg		 0
		> protocol fee_bal	 159957191
		> protocol fee_chg	 37473245
		> GSA_bal		 99999925659246
		> GSA_chg		 16037029

		GNS POSITION
		> tokenId: 1 amount: 0
	*/

	curr = printInfo(curr)
}
