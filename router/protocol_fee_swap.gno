package router

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
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
		transferFromByRegisterCall(outputToken, std.PrevRealm().Addr(), consts.PROTOCOL_FEE_ADDR, feeAmountUint64)

		prevAddr, prevRealm := getPrev()

		std.Emit(
			"SwapRouteFee",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_tokenPath", outputToken,
			"internal_amount", ufmt.Sprintf("%d", feeAmountUint64),
		)
	}

	toUserAfterProtocol := new(u256.Uint).Sub(amount, feeAmount)
	return toUserAfterProtocol
}

// GetSwapFee returns current rate of swap fee
// ref: https://docs.gnoswap.io/contracts/router/protocol_fee_swap.gno#getswapfee
func GetSwapFee() uint64 {
	return swapFee
}

func SetSwapFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setSwapFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetSwapFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetSwapFee modifies the swap fee
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/router/protocol_fee_swap.gno#setswapfee
func SetSwapFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setSwapFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetSwapFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

func setSwapFee(fee uint64) {
	common.IsHalted()

	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(addDetailToError(
			errInvalidSwapFee,
			ufmt.Sprintf("protocol_fee_swap.gno__setSwapFee() || fee(%d) must be in range 0 ~ 10000", fee),
		))
	}

	swapFee = fee
}
