package staker

import (
	"std"

	"gno.land/r/demo/consts"

	"gno.land/p/demo/ufmt"
)

var (
	rewardFee = bigint(1)
)

func handleRewardFee(
	tokenPath string,
	amount bigint,
	internal bool,
) bigint {
	if rewardFee == 0 {
		return amount
	}

	feeAmount := amount * rewardFee / bigint(100)

	if internal { // if internal, reward is in IRA
		ok := transferFromByRegisterCall(tokenPath, consts.INTERNAL_REWARD_ACCOUNT, consts.FEE_COLLECTOR, uint64(feeAmount))
		require(ok, ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", tokenPath, consts.INTERNAL_REWARD_ACCOUNT, consts.FEE_COLLECTOR, feeAmount))
	} else { // if external, reward is in staker contract
		ok := transferByRegisterCall(tokenPath, consts.FEE_COLLECTOR, uint64(feeAmount))
		require(ok, ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.FEE_COLLECTOR, feeAmount))
	}

	return amount - feeAmount
}

func SetRewardFee(fee bigint) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	// MUST BE ADMIN
	require(consts.GNOSWAP_ADMIN == std.GetOrigCaller(), ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || caller(%s) must be admin", std.GetOrigCaller()))

	require(fee >= 0, ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || fee(%d) must be >= 0", fee))

	rewardFee = fee
}
