package pool

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// withdrawalFee is the fee that is charged when a user withdraws their collected fees
var (
	withdrawalFee = uint64(100) // 1%
)

// HandleWithdrawalFee withdraws the fee from the user and returns the amount after the fee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#handlewithdrawalfee
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
	caller := std.PrevRealm().Addr()
	if caller != consts.POSITION_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("withdrawal_fee.gno__HandleWithdrawalFee() || only position(%s) can call this function, called from %s", consts.POSITION_ADDR, caller.String()),
		))
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

	transferFromByRegisterCall(token0Path, positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount0.Uint64())
	transferFromByRegisterCall(token1Path, positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount1.Uint64())

	afterAmount0 := new(u256.Uint).Sub(amount0, feeAmount0)
	afterAmount1 := new(u256.Uint).Sub(amount1, feeAmount1)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"WithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"internal_fee0Amount", feeAmount0.ToString(),
		"internal_fee1Amount", feeAmount1.ToString(),
	)

	return afterAmount0.ToString(), afterAmount1.ToString()
}

// GetWithdrawalFee returns the withdrawal fee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#getwithdrawalfee
func GetWithdrawalFee() uint64 {
	return withdrawalFee
}

func SetWithdrawalFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setWithdrawalFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetWithdrawalFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetWithdrawalFee sets the withdrawal fee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#setwithdrawalfee
func SetWithdrawalFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setWithdrawalFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetWithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

func setWithdrawalFee(fee uint64) {
	common.IsHalted()

	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(addDetailToError(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("withdrawal_fee.gno__setWithdrawalFee() || fee(%d) must be in range 0 ~ 10000", fee),
		))
	}

	withdrawalFee = fee
}
