package pool

import (
	"std"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

var (
	// poolCreationFee is the fee that is charged when a user creates a pool.
	// The fee is denominated in GNS tokens.
	// This parameter can be modified through governance.
	poolCreationFee = int64(100_000_000) // 100_GNS

	// withdrawalFeeBPS is the fee that is charged when a user withdraws their collected fees
	// The fee is denominated in BPS (Basis Points)
	// Example: 100 BPS = 1%
	// This parameter can be modified through governance.
	withdrawalFeeBPS = uint64(100) // 1%
)

const (
	MaxBpsValue = uint64(10000)
	ZeroBps     = uint64(0)
)

// HandleWithdrawalFee withdraws the fee from the user and returns the amount after the fee
// Only position contract can call this function
// Input:
// - positionId: the id of the LP token
// - token0Path: the path of the token0
// - amount0: the amount of token0
// - token1Path: the path of the token1
// - amount1: the amount of token1
// - poolPath: the path of the pool
// - positionCaller: the original caller of the position contract
// Output:
// - the amount of token0 after the fee
// - the amount of token1 after the fee
func HandleWithdrawalFee(
	cur realm,
	positionId uint64,
	token0Path string,
	amount0 string, // uint256
	token1Path string,
	amount1 string, // uint256
	poolPath string,
	positionCaller std.Address,
) (string, string) { // uint256 x2
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()

	// only position contract can call this function
	caller := std.PreviousRealm().Address()
	access.AssertIsPosition(caller)

	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

	fee := GetWithdrawalFee()
	if fee == ZeroBps {
		return amount0, amount1
	}

	feeAmount0, afterAmount0 := calculateAmountWithFee(u256.MustFromDecimal(amount0), u256.NewUint(fee))
	feeAmount1, afterAmount1 := calculateAmountWithFee(u256.MustFromDecimal(amount1), u256.NewUint(fee))

	checkTransferError(common.TransferFrom(cross, token0Path, positionCaller, protocolFeeAddr, safeConvertToInt64(feeAmount0)))
	pf.AddToProtocolFee(cross, token0Path, safeConvertToInt64(feeAmount0))
	checkTransferError(common.TransferFrom(cross, token1Path, positionCaller, protocolFeeAddr, safeConvertToInt64(feeAmount1)))
	pf.AddToProtocolFee(cross, token1Path, safeConvertToInt64(feeAmount1))

	previousRealm := std.PreviousRealm()
	std.Emit(
		"WithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", formatUint(positionId),
		"poolPath", poolPath,
		"feeAmount0", feeAmount0.ToString(),
		"feeAmount1", feeAmount1.ToString(),
		"amount0WithoutFee", afterAmount0.ToString(),
		"amount1WithoutFee", afterAmount1.ToString(),
	)

	return afterAmount0.ToString(), afterAmount1.ToString()
}

// GetPoolCreationFee returns the poolCreationFee
func GetPoolCreationFee() int64 {
	return poolCreationFee
}

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
func SetPoolCreationFee(cur realm, fee int64) {
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	prevPoolCreationFee := GetPoolCreationFee()
	err := setPoolCreationFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetPoolCreationFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatInt(prevPoolCreationFee),
		"newFee", formatInt(fee),
	)
}

// GetWithdrawalFee returns the withdrawal fee
func GetWithdrawalFee() uint64 {
	return withdrawalFeeBPS
}

// SetWithdrawalFee sets the withdrawal fee.
// Only admin or governance can call this function.
func SetWithdrawalFee(cur realm, fee uint64) {
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	prevWithdrawalFee := GetWithdrawalFee()

	err := setWithdrawalFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetWithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatUint(prevWithdrawalFee),
		"newFee", formatUint(fee),
	)
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
func calculateAmountWithFee(amount, fee *u256.Uint) (feeAmount, afterAmount *u256.Uint) {
	feeAmount = u256.Zero().Mul(amount, fee)
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(MaxBpsValue))
	afterAmount = u256.Zero().Sub(amount, feeAmount)
	return
}

// setPoolCreationFee this function is internal function called by SetPoolCreationFee
// And SetPoolCreationFee
func setPoolCreationFee(fee int64) error {
	if fee < 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			"pool creation fee cannot be negative",
		)
	}

	// update pool creation fee
	poolCreationFee = fee

	return nil
}

// setWithdrawalFee this function is internal function called by SetWithdrawalFee
// function and SetWithdrawalFee function
func setWithdrawalFee(fee uint64) error {
	if fee > MaxBpsValue {
		return makeErrorWithDetails(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ 10000", fee),
		)
	}

	withdrawalFeeBPS = fee

	return nil
}
