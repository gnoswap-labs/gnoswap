package router

import (
	"std"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/demo/gnoswap/uint256"

	"gno.land/r/demo/wugnot"
)

var (
	swapFee = uint64(15) // 0.15% // currently, chanageable by admin
)

func handleSwapFee(
	outputToken string,
	amount *u256.Uint,
	isDry bool,
) *u256.Uint {
	if swapFee <= 0 {
		return amount
	}

	feeAmount := new(u256.Uint).Mul(amount, u256.NewUint(swapFee))
	feeAmount.Div(feeAmount, u256.NewUint(10000))
	feeAmountUint64 := feeAmount.Uint64()

	if !isDry {
		if outputToken == consts.GNOT { // unwrap if coin
			// wugnot: buyer > router
			transferFromByRegisterCall(outputToken, std.GetOrigCaller(), consts.ROUTER_ADDR, feeAmountUint64)

			// ugnot: wugnot > router
			wugnot.Withdraw(feeAmountUint64)

			// ugnot: router > feeCollector
			banker := std.GetBanker(std.BankerTypeRealmSend)
			banker.SendCoins(consts.ROUTER_ADDR, consts.FEE_COLLECTOR, std.Coins{{"ugnot", int64(feeAmountUint64)}})
		} else { // just transfer if grc20
			ok := transferFromByRegisterCall(outputToken, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmountUint64)
			if !ok {
				panic(ufmt.Sprintf("[ROUTER] router.gno__handleSwapFee() || expected transferFromByRegisterCall(%s, %s, %s, %d) == true", outputToken, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmountUint64))
			}
		}
	}

	toUserAfterProtocol := new(u256.Uint).Sub(amount, feeAmount)
	return toUserAfterProtocol
}

func GetSwapFee() uint64 {
	return swapFee
}

func SetSwapFee(fee uint64) {
	common.MustCallFromAdmin()

	if fee > 100 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetSwapFee() || fee(%d) must be in range 0 ~ 100", fee))
	}

	swapFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
