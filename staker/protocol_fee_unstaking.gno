package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

var (
	unstakingFee = uint64(100) // 1%
)

// handleUnstakingFee calculates and applies the unstaking fee.
//
// The function deducts a fee from the unstaked amount based on the `unstakingFee` rate,
// sends the fee to the protocol fee address, and emits an event indicating the fee transfer.
//
// Parameters:
// - tokenPath (string): The token path (e.g., the contract managing the token).
// - amount (uint64): The total unstaked amount.
// - internal (bool): Indicates if the fee is for internal or external use.
// - tokenId (uint64): The token ID associated with the unstaking action.
// - poolPath (string): The pool path related to the unstaking.
//
// Returns:
// - uint64: The amount after deducting the unstaking fee.
func handleUnstakingFee(
	tokenPath string,
	amount uint64,
	internal bool,
	tokenId uint64,
	poolPath string,
) uint64 {
	if unstakingFee == 0 {
		return amount
	}

	feeAmount := amount * unstakingFee / 10000
	if feeAmount == 0 {
		return amount
	}

	prevAddr, prevRealm := getPrev()

	if internal {
		// staker contract has fee
		gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), feeAmount)
		std.Emit(
			"ProtocolFeeInternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", poolPath,
			"internal_tokenPath", consts.GNS_PATH,
			"internal_amount", ufmt.Sprintf("%d", feeAmount),
		)
	} else {
		// external contract has fee
		teller := common.GetTokenTeller(tokenPath)
		teller.Transfer(consts.PROTOCOL_FEE_ADDR, feeAmount)

		std.Emit(
			"ProtocolFeeExternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", poolPath,
			"internal_tokenPath", tokenPath,
			"internal_amount", ufmt.Sprintf("%d", feeAmount),
		)
	}

	return amount - feeAmount
}

// GetUnstakingFee returns current rate of unstaking fee
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#getunstakingfee
func GetUnstakingFee() uint64 {
	return unstakingFee
}

// SetUnstakingFeeByAdmin sets the unstaking fee rate by an admin.
//
// This function ensures that only admins can modify the unstaking fee. It validates
// the input fee and emits an event indicating the change.
//
// Parameters:
// - fee (uint64): The new unstaking fee rate in basis points (bps).
//
// Panics:
// - If the caller is not an admin.
func SetUnstakingFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}

	setUnstakingFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetUnstakingFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

// SetUnstakingFee modifies the unstaking fee
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/staker/protocol_fee_unstaking.gno#setunstakingfee
func SetUnstakingFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"reward_fee.gno__SetUnstakingFee() || only governance(%s) can set unstaking fee, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	setUnstakingFee(fee)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetUnstakingFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"fee", ufmt.Sprintf("%d", fee),
	)
}

func setUnstakingFee(fee uint64) {
	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(addDetailToError(
			errInvalidUnstakingFee,
			ufmt.Sprintf("reward_fee.gno__SetUnstakingFee() || fee(%d) must be in range 0 ~ 10000", fee),
		))
	}

	unstakingFee = fee
}
