package staker

import (
	"std"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/demo/gnoswap/uint256"
)

var (
	rewardFee = uint64(1) // currently, chanageable by admin
)

func handleRewardFee(
	tokenPath string,
	amount *u256.Uint,
	internal bool,
) *u256.Uint {
	if rewardFee == 0 {
		return amount
	}

	feeAmount := new(u256.Uint).Mul(amount, u256.NewUint(rewardFee))
	feeAmount.Div(feeAmount, u256.NewUint(100))

	if internal { // if internal, reward is in IRA
		ok := transferFromByRegisterCall(tokenPath, consts.INTERNAL_REWARD_ACCOUNT, consts.FEE_COLLECTOR, feeAmount.Uint64())
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", tokenPath, consts.INTERNAL_REWARD_ACCOUNT, consts.FEE_COLLECTOR, feeAmount.ToString()))
		}
	} else { // if external, reward is in staker contract
		ok := transferByRegisterCall(tokenPath, consts.FEE_COLLECTOR, feeAmount.Uint64())
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.FEE_COLLECTOR, feeAmount.ToString()))
		}
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", "INDIRECT",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenPath", tokenPath,
		"p_internal", boolToStr(internal),
		"feeAmount", feeAmount.ToString(),
	)

	return new(u256.Uint).Sub(amount, feeAmount)
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
