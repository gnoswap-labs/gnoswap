package staker

import (
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/big/uint256"
)

var (
	rewardFee = uint64(1)
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

	return new(u256.Uint).Sub(amount, feeAmount)
}

func SetRewardFee(fee uint64) {
	common.MustCallFromAdmin()

	if fee < 0 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || fee(%d) must be >= 0", fee))
	}

	rewardFee = fee
}
