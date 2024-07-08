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
	rewardFee = uint64(1) // 0.1%
)

func handleRewardFee(
	tokenPath string,
	amount uint64,
	internal bool,
) uint64 {
	if rewardFee == 0 {
		return amount
	}

	feeAmount := amount * rewardFee / 100
	if feeAmount == 0 {
		return amount
	}

	if internal {
		// staker contract has fee
		gns.Transfer(a2u(consts.FEE_COLLECTOR), feeAmount)
	} else {
		// external contract has fee
		ok := transferByRegisterCall(tokenPath, consts.FEE_COLLECTOR, feeAmount)
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.FEE_COLLECTOR, u256.NewUint(feeAmount).ToString()))
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

func GetRewardFee() uint64 {
	return rewardFee
}

func SetRewardFee(fee uint64) {
	common.MustCallFromAdmin()

	if fee > 100 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetRewardFee() || fee(%d) must be in range 0 ~ 100", fee))
	}

	rewardFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
