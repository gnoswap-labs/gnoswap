package v1

import (
	"chain"
	"chain/runtime"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pf "gno.land/r/gnoswap/protocol_fee"
)

const (
	MaxBpsValue = uint64(1000) // 10%
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
func (i *poolV1) HandleWithdrawalFee(
	positionId uint64,
	token0Path string,
	amount0 string, // uint256
	token1Path string,
	amount1 string, // uint256
	poolPath string,
	positionCaller address,
) (string, string) { // uint256 x2
	halt.AssertIsNotHaltedPoolWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	// only position contract can call this function
	caller := runtime.PreviousRealm().Address()
	access.AssertIsPositionWithVersion(1, caller)

	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

	fee := i.store.GetWithdrawalFeeBPS()
	if fee == ZeroBps {
		return amount0, amount1
	}

	feeAmount0, afterAmount0 := calculateAmountWithFee(u256.MustFromDecimal(amount0), u256.NewUint(fee))
	feeAmount1, afterAmount1 := calculateAmountWithFee(u256.MustFromDecimal(amount1), u256.NewUint(fee))

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	pf.AddToProtocolFee(cross, token0Path, safeConvertToInt64(feeAmount0))
	common.SafeGRC20TransferFrom(cross, token0Path, positionCaller, protocolFeeAddr, safeConvertToInt64(feeAmount0))
	pf.AddToProtocolFee(cross, token1Path, safeConvertToInt64(feeAmount1))
	common.SafeGRC20TransferFrom(cross, token1Path, positionCaller, protocolFeeAddr, safeConvertToInt64(feeAmount1))

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
func (i *poolV1) SetPoolCreationFee(fee int64) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	prevPoolCreationFee := i.store.GetPoolCreationFee()
	err := i.setPoolCreationFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetPoolCreationFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatInt(prevPoolCreationFee),
		"newFee", formatInt(fee),
	)
}

// SetWithdrawalFee sets the withdrawal fee.
// Only admin or governance can call this function.
func (i *poolV1) SetWithdrawalFee(fee uint64) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	prevWithdrawalFee := i.store.GetWithdrawalFeeBPS()

	err := i.setWithdrawalFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
	feeAmount, overflow := u256.Zero().MulOverflow(amount, fee)
	if overflow {
		panic(errOverFlow)
	}
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(MaxBpsValue))
	afterAmount = u256.Zero().Sub(amount, feeAmount)
	return feeAmount, afterAmount
}

// setPoolCreationFee this function is internal function called by SetPoolCreationFee
// And SetPoolCreationFee
func (i *poolV1) setPoolCreationFee(fee int64) error {
	if fee < 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			"pool creation fee cannot be negative",
		)
	}

	// update pool creation fee
	err := i.store.SetPoolCreationFee(fee)
	if err != nil {
		return err
	}

	return nil
}

// setWithdrawalFee this function is internal function called by SetWithdrawalFee
// function and SetWithdrawalFee function
func (i *poolV1) setWithdrawalFee(fee uint64) error {
	if fee > MaxBpsValue {
		return makeErrorWithDetails(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ %d", fee, MaxBpsValue),
		)
	}

	err := i.store.SetWithdrawalFeeBPS(fee)
	if err != nil {
		return err
	}

	return nil
}
