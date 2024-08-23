package position

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v2/gns"
)

func init() {
	// set pool create fee to 0 for testing
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)
	pl.SetPoolCreationFee(0)
}

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	pl.CreatePool(consts.GNOT, consts.GNS_PATH, fee500, common.TickMathGetSqrtRatioAtTick(1).ToString())
}

func TestMintPosition01InRange(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	wugnot.Approve(a2u(consts.POSITION_ADDR), consts.UINT64_MAX) // FOR WRAP

	std.TestIssueCoins(gsa, std.Coins{{"ugnot", 50000005}})
	shouldEQ(t, ugnotBalanceOf(gsa), uint64(50000005))
	shouldEQ(t, ugnotBalanceOf(consts.POSITION_ADDR), uint64(200000000))

	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(gsa, consts.POSITION_ADDR, std.Coins{{"ugnot", 50000005}})
	std.TestSetOrigSend(std.Coins{{"ugnot", 50000005}}, nil)
	shouldEQ(t, ugnotBalanceOf(gsa), uint64(0))

	gsaOldWugnotBalance := wugnot.BalanceOf(a2u(gsa))
	shouldEQ(t, gsaOldWugnotBalance, uint64(0))

	tokenId, liquidity, amount0, amount1 := Mint(
		consts.GNOT,
		consts.GNS_PATH,
		fee500,
		-8000,
		8000,
		"50000000",
		"50000000",
		"0",
		"0",
		max_timeout,
		gsa.String(),
	)
	std.TestSetOrigSend(std.Coins{{"ugnot", 0}}, nil)

	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, getNextId(), uint64(2))
	shouldEQ(t, amount0, "49984837")
	shouldEQ(t, amount1, "50000000")

	position := positions[tokenId]
	shouldEQ(t, position.nonce.ToString(), "0")
	shouldEQ(t, position.operator, gsa)
	shouldEQ(t, position.poolKey, "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:500")
	shouldEQ(t, position.tickLower, int32(-8000))
	shouldEQ(t, position.tickUpper, int32(8000))
	shouldEQ(t, position.liquidity.ToString(), "151645407")
	shouldEQ(t, position.feeGrowthInside0LastX128.ToString(), "0")
	shouldEQ(t, position.feeGrowthInside1LastX128.ToString(), "0")
	shouldEQ(t, position.tokensOwed0.ToString(), "0")
	shouldEQ(t, position.tokensOwed1.ToString(), "0")
	shouldEQ(t, position.burned, false)

	// SPEND ALL WUGNOT
	shouldEQ(t, wugnot.BalanceOf(a2u(gsa)), uint64(0))

	shouldEQ(t, ugnotBalanceOf(gsa), uint64(15168))
}

func TestUnclaimedFee0(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "0")
	shouldEQ(t, amount1.ToString(), "0")
}

func TestSwap1(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	// wrap some ugnot
	std.TestSetOrigSend(std.Coins{{"ugnot", 1234567}}, nil)
	wugnot.Deposit()

	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.POSITION_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	std.TestSetRealm(rouRealm)
	std.TestSetOrigCaller(gsa)
	amount0, amount1 := pl.Swap(
		consts.WUGNOT_PATH,
		consts.GNS_PATH,
		fee500,
		gsa.String(),
		true,
		"1234567",
		consts.MIN_PRICE,
		gsa.String(),
	)

	shouldEQ(t, amount0, "1234567")
	shouldEQ(t, amount1, "-1224110")

	position := positions[uint64(1)]
	shouldEQ(t, position.nonce.ToString(), "0")
	shouldEQ(t, position.operator, gsa)
	shouldEQ(t, position.poolKey, "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:500")
	shouldEQ(t, position.tickLower, int32(-8000))
	shouldEQ(t, position.tickUpper, int32(8000))
	shouldEQ(t, position.liquidity.ToString(), "151645407")
	shouldEQ(t, position.feeGrowthInside0LastX128.ToString(), "0")
	shouldEQ(t, position.feeGrowthInside1LastX128.ToString(), "0")
	shouldEQ(t, position.tokensOwed0.ToString(), "0")
	shouldEQ(t, position.tokensOwed1.ToString(), "0")
	shouldEQ(t, position.burned, false)
}

func TestUnclaimedFeePos01Swap01(t *testing.T) {
	amount0, amount1 := unclaimedFee(1)

	shouldEQ(t, amount0.ToString(), "617")
	shouldEQ(t, amount1.ToString(), "0")
}

func TestDecreaseWithNoUnwrap(t *testing.T) {
	// no unwrap => receive with wugnot

	oldWugnotBalance := wugnot.BalanceOf(a2u(gsa))
	oldUgnotBalance := ugnotBalanceOf(gsa)
	shouldEQ(t, oldWugnotBalance, uint64(0))
	shouldEQ(t, oldUgnotBalance, uint64(15168))

	std.TestSetRealm(gsaRealm)
	DecreaseLiquidity(
		uint64(1),
		uint64(10),
		"0",
		"0",
		int64(9999999999),
		false,
	)

	newWugnotBalance := wugnot.BalanceOf(a2u(gsa))
	newUgnotBalance := ugnotBalanceOf(gsa)

	shouldEQ(t, newWugnotBalance, uint64(5122489))
	shouldEQ(t, newUgnotBalance, uint64(15168)) // stays same, we didn't unwrap
}

func TestDecreaseWithUnwrap(t *testing.T) {
	// unwrap => receive with ugnot

	oldWugnotBalance := wugnot.BalanceOf(a2u(gsa))
	oldUgnotBalance := ugnotBalanceOf(gsa)
	shouldEQ(t, oldWugnotBalance, uint64(5122489))
	shouldEQ(t, oldUgnotBalance, uint64(15168))

	std.TestSetRealm(gsaRealm)
	DecreaseLiquidity(
		uint64(1),
		uint64(10),
		"0",
		"0",
		int64(9999999999),
		true,
	)

	newWugnotBalance := wugnot.BalanceOf(a2u(gsa))
	newUgnotBalance := ugnotBalanceOf(gsa)

	shouldEQ(t, newWugnotBalance, uint64(5122489))
	shouldEQ(t, newUgnotBalance, uint64(4624858))
}
