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
) bigint {
	if rewardFee == 0 {
		return amount
	}

	feeAmount := amount * rewardFee / bigint(100)
	ok := transferFromByRegisterCall(tokenPath, GetOrigCaller(), consts.FEE_COLLECTOR, uint64(feeAmount))
	require(ok, ufmt.Sprintf("[STAKER] reward_fee.gno__HandleRewardFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", tokenPath, GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount))

	return amount - feeAmount
}

func SetRewardFee(fee bigint) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	// MUST BE ADMIN
	require(consts.GNOSWAP_ADMIN == GetOrigCaller(), ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || caller(%s) must be admin", GetOrigCaller()))

	require(fee >= 0, ufmt.Sprintf("[STAKER] reward_fee.gno__SetFeeProtocol() || fee(%d) must be >= 0", fee))

	rewardFee = fee
}
