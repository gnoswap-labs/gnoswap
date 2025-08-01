package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

var (
	// poolCreationFee is the fee that is charged when a user creates a pool.
	// The fee is denominated in GNS tokens.
	poolCreationFee = int64(100_000_000) // 100_GNS

	// withdrawalFeeBPS is the fee that is charged when a user withdraws their collected fees
	// The fee is denominated in BPS (Basis Points)
	// Example: 100 BPS = 1%
	withdrawalFeeBPS = uint64(100) // 1%
)

const (
	MaxBpsValue = uint64(10000)
	ZeroBps     = uint64(0)
)

// GetPoolCreationFee returns the poolCreationFee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_pool_creation.gno#getpoolcreationfee
func GetPoolCreationFee() int64 {
	return poolCreationFee
}

// SetPoolCreationFee sets the poolCreationFee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_pool_creation.gno#setpoolcreationfee
func SetPoolCreationFee(cur realm, fee int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedPool()
	access.AssertIsGovernance(caller)

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

// SetPoolCreationFeeByAdmin sets the poolCreationFee by Admin.
// Only admin can execute this function.
func SetPoolCreationFeeByAdmin(cur realm, fee int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedPool()
	access.AssertIsAdmin(caller)

	prevPoolCreationFee := GetPoolCreationFee()
	err := setPoolCreationFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetPoolCreationFeeByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatInt(prevPoolCreationFee),
		"newFee", formatInt(fee),
	)
}

// GetWithdrawalFee returns the withdrawal fee
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#getwithdrawalfee
func GetWithdrawalFee() uint64 {
	return withdrawalFeeBPS
}

// SetWithdrawalFee sets the withdrawal fee.
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/pool/protocol_fee_withdrawal.gno#setwithdrawalfee
func SetWithdrawalFee(cur realm, fee uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedPool()
	access.AssertIsGovernance(caller)

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

// SetWithdrawalFeeByAdmin sets the withdrawal fee by Admin.
// Only admin can execute this function.
func SetWithdrawalFeeByAdmin(cur realm, fee uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedPool()
	access.AssertIsAdmin(caller)

	prevWithdrawalFee := GetWithdrawalFee()

	err := setWithdrawalFee(fee)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetWithdrawalFeeByAdmin",
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
func calculateAmountWithFee(amount *u256.Uint, fee *u256.Uint) (*u256.Uint, *u256.Uint) {
	feeAmount := new(u256.Uint).Mul(amount, fee)
	feeAmount = new(u256.Uint).Div(feeAmount, u256.NewUint(MaxBpsValue))
	afterAmount := new(u256.Uint).Sub(amount, feeAmount)
	return feeAmount, afterAmount
}

// setPoolCreationFee this function is internal function called by SetPoolCreationFee
// And SetPoolCreationFeeByAdmin
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
// function and SetWithdrawalFeeByAdmin function
func setWithdrawalFee(fee uint64) error {
	// 10000 (bps) = 100%
	if fee > MaxBpsValue {
		return makeErrorWithDetails(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ 10000", fee),
		)
	}

	// update withdrawal fee
	withdrawalFeeBPS = fee

	return nil
}
