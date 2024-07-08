package staker

import (
	"std"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/demo/gnoswap/uint256"

	"gno.land/r/demo/gns"
)

var (
	unstakingFee = uint64(10) // 0.1%
)

func handleUnstakingFee(
	tokenPath string,
	amount uint64,
	internal bool,
) uint64 {
	if unstakingFee == 0 {
		return amount
	}

	feeAmount := amount * unstakingFee / 100
	if feeAmount == 0 {
		return amount
	}

	if internal {
		// staker contract has fee
		gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), feeAmount)
	} else {
		// external contract has fee
		ok := transferByRegisterCall(tokenPath, consts.PROTOCOL_FEE_ADDR, feeAmount)
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__handleUnstakingFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.PROTOCOL_FEE_ADDR, u256.NewUint(feeAmount).ToString()))
		}
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", "INDIRECT",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenPath", tokenPath,
		"p_internal", boolToStr(internal),
		"feeAmount", uint64ToStr(feeAmount),
	)

	return amount - feeAmount
}

func GetUnstakingFee() uint64 {
	return unstakingFee
}

func SetUnstakingFee(fee uint64) {
	common.MustCallFromAdmin()

	if fee > 10000 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetUnstakingFee() || fee(%d) must be in range 0 ~ 10000", fee))
	}

	unstakingFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
