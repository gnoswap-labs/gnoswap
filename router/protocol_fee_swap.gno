package router

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/wugnot"
)

var (
	swapFee = uint64(15) // 0.15%
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
			transferFromByRegisterCall(outputToken, std.PrevRealm().Addr(), consts.ROUTER_ADDR, feeAmountUint64)

			// ugnot: wugnot > router
			wugnot.Withdraw(feeAmountUint64)

			// ugnot: router > feeCollector
			banker := std.GetBanker(std.BankerTypeRealmSend)
			banker.SendCoins(consts.ROUTER_ADDR, consts.PROTOCOL_FEE_ADDR, std.Coins{{"ugnot", int64(feeAmountUint64)}})
		} else { // just transfer if grc20
			ok := transferFromByRegisterCall(outputToken, std.PrevRealm().Addr(), consts.PROTOCOL_FEE_ADDR, feeAmountUint64)
			if !ok {
				panic(ufmt.Sprintf("[ROUTER] protocol_fee_swap.gno__handleSwapFee() || expected transferFromByRegisterCall(%s, %s, %s, %d) == true", outputToken, std.PrevRealm().Addr(), consts.PROTOCOL_FEE_ADDR, feeAmountUint64))
			}
		}

		std.Emit(
			"SwapRouteFee"
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_token", outputToken,
			"internal_amount", strconv.FormatUint(feeAmountUint64, 10),
		)
	}

	toUserAfterProtocol := new(u256.Uint).Sub(amount, feeAmount)
	return toUserAfterProtocol
}

func GetSwapFee() uint64 {
	return swapFee
}

func SetSwapFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(
			ufmt.Sprintf(
				"[ROUTER] protocol_fee_swap.gno__SetSwapFeeByAdmin() || only admin(%s) can set swap fee, called from %s",
				consts.ADMIN,
				caller,
			),
		)
	}

	setSwapFee(fee)
	std.Emit(
		"SetSwapFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", uint64ToStr(fee),
	)
}

func SetSwapFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[ROUTER] protocol_fee_swap.gno__SetSwapFee() || only governance(%s) can set swap fee, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setSwapFee(fee)
	std.Emit(
		"SetSwapFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", uint64ToStr(fee),
	)
}

func setSwapFee(fee uint64) {
	common.IsHalted()

	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(ufmt.Sprintf("[ROUTER] protocol_fee_swap.gno__SetSwapFee() || fee(%d) must be in range 0 ~ 10000", fee))
	}

	swapFee = fee
}
