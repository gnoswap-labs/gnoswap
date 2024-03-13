package pool

import (
	"std"

	"gno.land/r/demo/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/big/uint256"
)

var (
	withdrawalFee = uint64(1)
)

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

	amount0, err := u256.FromDecimal(_amount0)
	if err != nil {
		ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() ||u256.FromDecimal(%s) failed", _amount0)
	}
	amount1, err := u256.FromDecimal(_amount1)
	if err != nil {
		ufmt.Sprintf("[POOL] withdrawal_fee.gno__HandleWithdrawFee() ||u256.FromDecimal(%s) failed", _amount1)
	}

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

func SetWithdrawalFee(fee uint64) {
	// MUST BE ORIGIN CALL
	std.AssertOriginCall()

	// MUST BE ADMIN
	if !(isAdmin(std.GetOrigCaller())) {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__SetFeeProtocol() || caller(%s) must be admin", std.GetOrigCaller()))
	}

	if fee < 0 {
		panic(ufmt.Sprintf("[POOL] withdrawal_fee.gno__SetFeeProtocol() || fee(%d) must be >= 0", fee))
	}

	withdrawalFee = fee
}
