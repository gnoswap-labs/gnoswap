package v1

import (
	"chain"
	"chain/runtime"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pf "gno.land/r/gnoswap/protocol_fee"
)

const (
	MaxBpsValue = uint64(1000) // 10%
	ZeroBps     = uint64(0)
)

// HandleWithdrawalFee settles collected fees from the pool and returns the amount after the fee.
// Only position contract can call this function
// Input:
// - token0Path: the path of the token0
// - amount0: the amount of token0
// - token1Path: the path of the token1
// - amount1: the amount of token1
// - positionCaller: the original caller of the position contract
// Output:
// - the fee amount of token0
// - the fee amount of token1
// - the amount of token0 after the fee
// - the amount of token1 after the fee
func (i *poolV1) HandleWithdrawalFee(
	token0Path string,
	amount0 string, // uint256
	token1Path string,
	amount1 string, // uint256
	positionCaller address,
) (string, string, string, string) {
	halt.AssertCanRecover(halt.OpTypePool)

	// only position contract can call this function
	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsPosition(caller)

	common.MustRegistered(token0Path, token1Path)

	fee := u256.NewUint(i.store.GetWithdrawalFeeBPS())
	fee0, amount0WithoutFee := calculateAmountWithFee(u256.MustFromDecimal(amount0), fee)
	fee1, amount1WithoutFee := calculateAmountWithFee(u256.MustFromDecimal(amount1), fee)

	fee0Int64 := safeConvertToInt64(fee0)
	fee1Int64 := safeConvertToInt64(fee1)

	// Withdrawal is part of the Emergency recovery surface, so we still record
	// protocol-fee accrual here even while protocol_fee claims/distribution stay halted.
	pf.AddToProtocolFee(cross, token0Path, fee0Int64)
	pf.AddToProtocolFee(cross, token1Path, fee1Int64)

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	common.SafeGRC20Transfer(cross, token0Path, protocolFeeAddr, fee0Int64)
	common.SafeGRC20Transfer(cross, token1Path, protocolFeeAddr, fee1Int64)
	common.SafeGRC20Transfer(cross, token0Path, positionCaller, safeConvertToInt64(amount0WithoutFee))
	common.SafeGRC20Transfer(cross, token1Path, positionCaller, safeConvertToInt64(amount1WithoutFee))

	return fee0.ToString(), fee1.ToString(), amount0WithoutFee.ToString(), amount1WithoutFee.ToString()
}

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
func (i *poolV1) SetPoolCreationFee(fee int64) {
	halt.AssertIsNotHaltedPool()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	prevPoolCreationFee := i.store.GetPoolCreationFee()
	err := i.setPoolCreationFee(fee)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetPoolCreationFee",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatInt(prevPoolCreationFee),
		"newFee", formatInt(fee),
	)
}

// SetWithdrawalFee sets the withdrawal fee.
// Only admin or governance can call this function.
func (i *poolV1) SetWithdrawalFee(fee uint64) {
	halt.AssertIsNotHaltedPool()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	prevWithdrawalFee := i.store.GetWithdrawalFeeBPS()

	err := i.setWithdrawalFee(fee)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetWithdrawalFee",
		"prevAddr", caller.String(),
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
		panic(errOverflow)
	}
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(10_000))
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
