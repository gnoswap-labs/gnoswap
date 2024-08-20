package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"
	pn "gno.land/r/gnoswap/v2/position"

	"gno.land/r/gnoswap/v2/gnft"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/onbloc/obl"
)

func init() {
	// set pool create fee to 0 for testing
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	pl.SetPoolCreationFee(0)
}

func init() {
	// init pool tiers
	// tier 1
	poolTiers["gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500"] = InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
		startHeight:    std.GetHeight(),
		updateHeight:   std.GetHeight(),
	}
}

func createPool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	std.TestSkipHeights(1)

	pl.CreatePool(barPath, quxPath, fee500, "130621891405341611593710811006") // tick 10_000 ≈ x2.7

	pl.CreatePool(consts.GNOT, consts.GNS_PATH, 500, "79228162514264337593543950337") // x1

	std.TestSkipHeights(1)
}

func TestStakeAndGetBack(t *testing.T) {
	//================ Create Pool =================
	std.TestSetRealm(gsaRealm)
	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	pl.CreatePool(barPath, quxPath, 500, "130621891405341611593710811006")
	std.TestSkipHeights(1)

	//================ Mint Position =================
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	std.TestSkipHeights(2)
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		barPath,      // token0
		quxPath,      // token1
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
	gnft.Approve(a2u(GetOrigPkgAddr()), tid(lpTokenId))
	std.TestSkipHeights(1)

	//================ Stake GNFT Token =================
	gnft.TransferFrom(a2u(gsa), a2u(consts.STAKER_ADDR), tid(lpTokenId))
	StakeToken(lpTokenId)
	gnft.TransferFrom(a2u(consts.STAKER_ADDR), a2u(gsa), tid(lpTokenId))
	owner := gnft.OwnerOf(tid(lpTokenId))
	if a2u(owner) != a2u(gsa) {
		t.Errorf("expected owner to be %s, got %s", a2u(gsa), a2u(owner))
	}
	std.TestSkipHeights(1)

	//================ Control GNFT Token Liquidity (Burn) =================
	pn.DecreaseLiquidity(
		lpTokenId,
		100,
		"0",
		"0",
		time.Now().Unix()+1000,
		false,
	)

	//================ Collect Reward From Position =================
	pn.CollectFee(lpTokenId)

	//================ Collect Reward From Staker =================
	CollectReward(lpTokenId, false)

	//================ Unstake GNFT Token =================
	gnft.TransferFrom(a2u(gsa), a2u(consts.STAKER_ADDR), tid(lpTokenId))
	UnstakeToken(lpTokenId, false)
}

func TestMintAndStakeAndGetBack(t *testing.T) {
	//================ Create Pool =================
	std.TestSetRealm(gsaRealm)
	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	pl.CreatePool(consts.GNOT, consts.GNS_PATH, 3000, "79228162514264337593543950337")
	std.TestSkipHeights(1)

	gns.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)    // MINT
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX) // MINT

	wugnot.Approve(a2u(consts.POSITION_ADDR), consts.UINT64_MAX) // WRAP

	std.TestSkipHeights(2)

	std.TestIssueCoins(gsa, std.Coins{{"ugnot", 100005}})

	// send & set orig send
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(gsa, consts.POSITION_ADDR, std.Coins{{"ugnot", 100005}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 100005}}, nil)

	gsaOldWugnotBalance := wugnot.BalanceOf(a2u(gsa))

	lpTokenId, liquidity, amount0, amount1, poolPath := MintAndStake(
		consts.GNOT,     // token0
		consts.GNS_PATH, // token1
		fee3000,         // fee
		int32(-5040),    // tickLower
		int32(5040),     // tickUpper
		"100000",        // amount0Desired
		"100000",        // amount1Desired
		"1",             // amount0Min
		"1",             // amount1Min
		max_timeout,
	)
	gnft.TransferFrom(a2u(consts.STAKER_ADDR), a2u(gsa), tid(lpTokenId))

	//================ Control GNFT Token Liquidity (Burn) =================
	pn.DecreaseLiquidity(
		lpTokenId,
		100,
		"0",
		"0",
		time.Now().Unix()+1000,
		false,
	)

	//================ Collect Reward From Position =================
	pn.CollectFee(lpTokenId)

	//================ Collect Reward From Staker =================
	CollectReward(lpTokenId, false)

	//================ Unstake GNFT Token =================
	gnft.TransferFrom(a2u(gsa), a2u(consts.STAKER_ADDR), tid(lpTokenId))
	UnstakeToken(lpTokenId, false)
}
