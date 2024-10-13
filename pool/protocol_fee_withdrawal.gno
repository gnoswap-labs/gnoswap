package pool

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// withdrawalFee is the fee that is charged when a user withdraws their collected fees
var (
	withdrawalFee = uint64(100) // 1%
)

// HandleWithdrawalFee withdraws the fee from the user and returns the amount after the fee
//
// Panics:
// - caller is not the position contract
// - caller does not have enough balance to give the fee
func HandleWithdrawalFee(
	tokenId uint64,
	token0Path string,
	_amount0 string, // uint256
	token1Path string,
	_amount1 string, // uint256
	poolPath string,
	positionCaller std.Address,
) (string, string) { // uint256 x2
	common.IsHalted()

	// only position contract can call this function
	if std.PrevRealm().PkgPath() != consts.POSITION_PATH {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawalFee() || expected std.PrevRealm().PkgPath()(%s), got %s", consts.POSITION_PATH, std.PrevRealm().PkgPath()))
	}

	amount0 := u256.MustFromDecimal(_amount0)
	amount1 := u256.MustFromDecimal(_amount1)

	if withdrawalFee == 0 {
		return _amount0, _amount1
	}

	feeAmount0 := new(u256.Uint).Mul(amount0, u256.NewUint(withdrawalFee))
	feeAmount0 = new(u256.Uint).Div(feeAmount0, u256.NewUint(10000))

	feeAmount1 := new(u256.Uint).Mul(amount1, u256.NewUint(withdrawalFee))
	feeAmount1 = new(u256.Uint).Div(feeAmount1, u256.NewUint(10000))

	ok := transferFromByRegisterCall(token0Path, positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount0.Uint64())
	if !ok {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawalFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token0Path, positionCaller.String(), consts.PROTOCOL_FEE_ADDR, feeAmount0))
	}

	ok = transferFromByRegisterCall(token1Path, positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount1.Uint64())
	if !ok {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawalFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token1Path, positionCaller.String(), consts.PROTOCOL_FEE_ADDR, feeAmount1))
	}

	afterAmount0 := new(u256.Uint).Sub(amount0, feeAmount0)
	afterAmount1 := new(u256.Uint).Sub(amount1, feeAmount1)

	std.Emit(
		"WithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"tokenId", uint64ToStr(tokenId),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"internal_fee0Amount", feeAmount0.ToString(),
		"internal_fee1Amount", feeAmount1.ToString(),
	)

	return afterAmount0.ToString(), afterAmount1.ToString()
}

// GetWithdrawalFee returns the withdrawal fee
func GetWithdrawalFee() uint64 {
	return withdrawalFee
}

func SetWithdrawalFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic(
			ufmt.Sprintf(
				"[POOL] protocol_fee_withdrawal.gno__SetWithdrawalFeeByAdmin() || only admin(%s) can set withdrawal fee, called from %s",
				consts.GNOSWAP_ADMIN,
				caller,
			),
		)
	}

	setWithdrawalFee(fee)
	std.Emit(
		"SetWithdrawalFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", uint64ToStr(fee),
	)
}

func SetWithdrawalFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[POOL] protocol_fee_withdrawal.gno__SetWithdrawalFee() || only governance(%s) can set withdrawal fee, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setWithdrawalFee(fee)
	std.Emit(
		"SetWithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", uint64ToStr(fee),
	)
}

func setWithdrawalFee(fee uint64) {
	common.IsHalted()

	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__setWithdrawalFee() || fee(%d) must be in range 0 ~ 10000", fee))
	}

	withdrawalFee = fee
}
