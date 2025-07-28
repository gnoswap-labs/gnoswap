package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

const FEE_PRECISION = 10000

var unstakingFee = uint64(100) // 1%

// handleUnStakingFee calculates and applies the unstaking fee.
//
// The function deducts a fee from the unstaked amount based on the `unstakingFee` rate,
// sends the fee to the protocol fee address, and emits an event indicating the fee transfer.
//
// Parameters:
// - tokenPath (string): The token path (e.g., the contract managing the token).
// - amount (uint64): The total unstaked amount.
// - internal (bool): Indicates if the fee is for internal or external use.
// - positionId (uint64): The token ID associated with the unstaking action.
// - poolPath (string): The pool path related to the unstaking.
//
// Returns:
// - uint64: The amount after deducting the unstaking fee.
func handleUnStakingFee(
	tokenPath string,
	amount int64,
	internal bool,
	positionId uint64,
	poolPath string,
) (int64, int64, error) {
	if unstakingFee == 0 {
		return amount, 0, nil
	}

	// Do not change the order of the operation.
	feeAmount := (amount * int64(unstakingFee)) / FEE_PRECISION
	if feeAmount < 0 {
		return 0, 0, ufmt.Errorf("fee amount cannot be negative")
	}

	if feeAmount == 0 {
		return amount, 0, nil
	}

	if internal {
		tokenPath = GNS_PATH
	}

	// external contract has fee
	common.Transfer(cross, tokenPath, protocolFeeAddr, feeAmount)
	pf.AddToProtocolFee(cross, tokenPath, uint64(feeAmount))

	return amount - feeAmount, feeAmount, nil
}

// GetUnstakingFee returns current rate of unstaking fee
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#getunstakingfee
func GetUnstakingFee() uint64 {
	return unstakingFee
}

// SetUnStakingFeeByAdmin sets the unstaking fee rate by an admin.
//
// This function ensures that only admins can modify the unstaking fee. It validates
// the input fee and emits an event indicating the change.
//
// Parameters:
// - fee (uint64): The new unstaking fee rate in basis points (bps).
//
// Panics:
// - If the caller is not an admin.
func SetUnStakingFeeByAdmin(cur realm, fee uint64) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdmin(caller)

	prevUnStakingFee := GetUnstakingFee()

	setUnStakingFee(fee)

	previousRealm := std.PreviousRealm()

	std.Emit(
		"SetUnStakingFeeByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatUint(prevUnStakingFee),
		"newFee", formatUint(fee),
	)
}

// SetUnStakingFee modifies the unstaking fee
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#setunstakingfee
func SetUnStakingFee(cur realm, fee uint64) {
	caller := std.PreviousRealm().Address()
	access.AssertIsGovernance(caller)

	prevUnStakingFee := GetUnstakingFee()

	setUnStakingFee(fee)

	previousRealm := std.PreviousRealm()

	std.Emit(
		"SetUnStakingFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatUint(prevUnStakingFee),
		"newFee", formatUint(fee),
	)
}

func setUnStakingFee(fee uint64) {
	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(makeErrorWithDetails(
			errInvalidUnstakingFee,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ 10000", fee),
		))
	}

	unstakingFee = fee
}
