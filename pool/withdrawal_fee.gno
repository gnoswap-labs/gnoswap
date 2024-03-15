package pool

import (
	"std"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/big/uint256"
)

// withdrawalFee is the fee that is charged when a user withdraws their collected fees
var (
	withdrawalFee = uint64(1)
)

// HandleWithdrawalFee withdraws the fee from the user and returns the amount after the fee
//
// Panics if any of the following conditions are met:
// - caller is not the position contract
// - caller does not have enough balance to give the fee
func HandleWithdrawalFee(
	tokenId uint64,
	token0Path string,
	_amount0 string, // uint256
	token1Path string,
	_amount1 string, // uint256
) (string, string) { // uint256 x2
	// only position contract can call this function
	if std.PrevRealm().PkgPath() != consts.POSITION_PATH {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected std.PrevRealm().PkgPath()(%s), got %s", consts.POSITION_PATH, std.PrevRealm().PkgPath()))
	}

	amount0 := u256.MustFromDecimal(_amount0)
	amount1 := u256.MustFromDecimal(_amount1)

	if withdrawalFee == 0 {
		return _amount0, _amount1
	}

	feeAmount0 := new(u256.Uint).Mul(amount0, u256.NewUint(withdrawalFee))
	feeAmount0 = new(u256.Uint).Div(feeAmount0, u256.NewUint(100))

	feeAmount1 := new(u256.Uint).Mul(amount1, u256.NewUint(withdrawalFee))
	feeAmount1 = new(u256.Uint).Div(feeAmount1, u256.NewUint(100))

	ok := transferFromByRegisterCall(token0Path, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount0.Uint64())
	if !ok {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token0Path, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount0))
	}

	ok = transferFromByRegisterCall(token1Path, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount1.Uint64())
	if !ok {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", token1Path, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount1))
	}

	afterAmount0 := new(u256.Uint).Sub(amount0, feeAmount0)
	afterAmount1 := new(u256.Uint).Sub(amount1, feeAmount1)

	return afterAmount0.ToString(), afterAmount1.ToString()
}

// SetWithdrawalFee sets the withdrawal fee
//
// Panics if any of the following conditions are met:
// - caller is not the admin
func SetWithdrawalFee(fee uint64) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	common.MustCallFromAdmin()

	if fee > 100 {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__SetFeeProtocol() || fee(%d) must be in range 0 ~ 100", fee))
	}

	withdrawalFee = fee
}
