package pool

import (
	"std"

	"gno.land/r/demo/consts"

	"gno.land/p/demo/ufmt"
)

var (
	withdrawalFee = bigint(1)
)

func HandleWithdrawalFee(
	tokenId uint64,
	token0Path string,
	amount0 bigint,
	token1Path string,
	amount1 bigint,
) (bigint, bigint) {
	requirePrevRealmPath(consts.POSITION_PATH, ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected PrevRealmPath(%s), got %s", consts.POSITION_PATH, PrevRealmPath()))

	if withdrawalFee == 0 {
		return amount0, amount1
	}

	feeAmount0 := amount0 * withdrawalFee / bigint(100)
	feeAmount1 := amount1 * withdrawalFee / bigint(100)

	ok := transferFromByRegisterCall(token0Path, GetOrigCaller(), consts.FEE_COLLECTOR, uint64(feeAmount0))
	require(ok, ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token0Path, GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount0))

	ok = transferFromByRegisterCall(token1Path, GetOrigCaller(), consts.FEE_COLLECTOR, uint64(feeAmount1))
	require(ok, ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token1Path, GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount1))

	return amount0 - feeAmount0, amount1 - feeAmount1
}

func SetWithdrawalFee(fee bigint) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	// MUST BE ADMIN
	require(isAdmin(GetOrigCaller()), ufmt.Sprintf("[POOL] withdrawal_fee.gno__SetFeeProtocol() || caller(%s) must be admin", GetOrigCaller()))

	require(fee >= 0, ufmt.Sprintf("[POOL] withdrawal_fee.gno__SetFeeProtocol() || fee(%d) must be >= 0", fee))

	withdrawalFee = fee
}
