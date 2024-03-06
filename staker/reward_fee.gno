package staker

import (
	"std"

	"gno.land/r/demo/consts"

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
		require(ok, ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", tokenPath, consts.INTERNAL_REWARD_ACCOUNT, consts.FEE_COLLECTOR, feeAmount))
	} else { // if external, reward is in staker contract
		ok := transferByRegisterCall(tokenPath, consts.FEE_COLLECTOR, feeAmount.Uint64())
		require(ok, ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.FEE_COLLECTOR, feeAmount))
	}

	return new(u256.Uint).Sub(amount, feeAmount)
}

func SetRewardFee(fee uint64) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	// MUST BE ADMIN
	require(consts.GNOSWAP_ADMIN == std.GetOrigCaller(), ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || caller(%s) must be admin", std.GetOrigCaller()))

	require(fee >= 0, ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || fee(%s) must be >= 0", fee))

	rewardFee = fee
}
