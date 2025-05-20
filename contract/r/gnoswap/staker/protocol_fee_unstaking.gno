package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

var unstakingFee = int64(100) // 1%

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
) int64 {
	if unstakingFee == 0 {
		return amount
	}

	feeAmount := amount * unstakingFee / 10000
	if feeAmount == 0 {
		return amount
	}
	fee := feeAmount

	prevAddr, prevPkgPath := getPrev()

	if internal {
		// staker contract has fee
		cross(gns.Transfer)(protocolFeeAddr, fee)
		pf.AddToProtocolFee(consts.GNS_PATH, fee)

		std.Emit(
			"ProtocolFeeInternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"fromPositionId", formatUint(positionId),
			"fromPoolPath", poolPath,
			"feeTokenPath", consts.GNS_PATH,
			"feeAmount", formatUint(feeAmount),
		)
	} else {
		// external contract has fee
		teller := common.GetTokenTeller(tokenPath)
		teller.Transfer(protocolFeeAddr, fee)
		pf.AddToProtocolFee(tokenPath, fee)

		std.Emit(
			"ProtocolFeeExternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"fromPositionId", formatUint(positionId),
			"fromPoolPath", poolPath,
			"feeTokenPath", tokenPath,
			"feeAmount", formatUint(feeAmount),
		)
	}

	return amount - feeAmount
}

// GetUnstakingFee returns current rate of unstaking fee
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#getunstakingfee
func GetUnstakingFee() int64 {
	return unstakingFee
}

// SetUnStakingFeeByAdmin sets the unstaking fee rate by an admin.
//
// This function ensures that only admins can modify the unstaking fee. It validates
// the input fee and emits an event indicating the change.
//
// Parameters:
// - fee (int64): The new unstaking fee rate in basis points (bps).
//
// Panics:
// - If the caller is not an admin.
func SetUnStakingFeeByAdmin(fee int64) {
	caller := std.PreviousRealm().Address()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}

	prevUnStakingFee := GetUnstakingFee()

	setUnStakingFee(fee)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetUnStakingFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevFee", formatUint(prevUnStakingFee),
		"newFee", formatUint(fee),
	)
}

// SetUnStakingFee modifies the unstaking fee
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#setunstakingfee
func SetUnStakingFee(fee int64) {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}

	prevUnStakingFee := GetUnstakingFee()

	setUnStakingFee(fee)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetUnStakingFee",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevFee", formatUint(prevUnStakingFee),
		"newFee", formatUint(fee),
	)
}

func setUnStakingFee(fee int64) {
	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(addDetailToError(
			errInvalidUnstakingFee,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ 10000", fee),
		))
	}

	unstakingFee = fee
}
