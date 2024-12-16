package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

// withdrawalFeeBPS is the fee that is charged when a user withdraws their collected fees
// The fee is denominated in BPS (Basis Points)
// Example: 100 BPS = 1%
var (
	withdrawalFeeBPS = uint64(100) // 1%
)

const (
	MaxBpsValue = uint64(10000)
	ZeroBps     = uint64(0)
)

// HandleWithdrawalFee withdraws the fee from the user and returns the amount after the fee
// Only position contract can call this function
// Input:
// - tokenId: the id of the LP token
// - token0Path: the path of the token0
// - _amount0: the amount of token0
// - token1Path: the path of the token1
// - _amount1: the amount of token1
// - poolPath: the path of the pool
// - positionCaller: the original caller of the position contract
// Output:
// - the amount of token0 after the fee
// - the amount of token1 after the fee
//
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
	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

	// only position contract can call this function
	caller := std.PrevRealm().Addr()
	if err := common.PositionOnly(caller); err != nil {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("withdrawal_fee.gno__HandleWithdrawalFee() || only position(%s) can call this function, called from %s", consts.POSITION_ADDR, caller.String()),
		))
	}

	fee := GetWithdrawalFee()
	if fee == ZeroBps {
		return _amount0, _amount1
	}

	feeAmount0, afterAmount0 := calculateAmountWithFee(u256.MustFromDecimal(_amount0), u256.NewUint(fee))
	feeAmount1, afterAmount1 := calculateAmountWithFee(u256.MustFromDecimal(_amount1), u256.NewUint(fee))

	token0Teller := common.GetTokenTeller(token0Path)
	checkTransferError(token0Teller.TransferFrom(positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount0.Uint64()))

	token1Teller := common.GetTokenTeller(token1Path)
	checkTransferError(token1Teller.TransferFrom(positionCaller, consts.PROTOCOL_FEE_ADDR, feeAmount1.Uint64()))

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"WithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"internal_fee0Amount", feeAmount0.ToString(),
		"internal_fee1Amount", feeAmount1.ToString(),
		"poolPath", poolPath,
	)

	return afterAmount0.ToString(), afterAmount1.ToString()
}

// GetWithdrawalFee returns the withdrawal fee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#getwithdrawalfee
func GetWithdrawalFee() uint64 {
	return withdrawalFeeBPS
}

// SetWithdrawalFee sets the withdrawal fee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#setwithdrawalfee
func SetWithdrawalFee(fee uint64) {
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}

	setWithdrawalFee(fee)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetWithdrawalFee",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetWithdrawalFeeByAdmin sets the withdrawal fee by Admin.
// Only admin can execute this function.
func SetWithdrawalFeeByAdmin(fee uint64) {
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}

	setWithdrawalFee(fee)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetWithdrawalFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// setWithdrawalFee this function is internal function called by SetWithdrawalFee
// function and SetWithdrawalFeeByAdmin function
func setWithdrawalFee(fee uint64) {
	// 10000 (bps) = 100%
	if fee > MaxBpsValue {
		panic(addDetailToError(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("withdrawal_fee.gno__setWithdrawalFee() || fee(%d) must be in range 0 ~ 10000", fee),
		))
	}
	withdrawalFeeBPS = fee
}

// calculateAmountWithFee calculates the fee amount and the amount after the fee
//
// Inputs:
// - amount: the amount before the fee
// - fee: the fee in BPS
//
// Outputs:
// - the fee amount
// - the amount after the fee applied
func calculateAmountWithFee(amount *u256.Uint, fee *u256.Uint) (*u256.Uint, *u256.Uint) {
	feeAmount := new(u256.Uint).Mul(amount, fee)
	feeAmount = new(u256.Uint).Div(feeAmount, u256.NewUint(MaxBpsValue))
	afterAmount := new(u256.Uint).Sub(amount, feeAmount)
	return feeAmount, afterAmount
}
