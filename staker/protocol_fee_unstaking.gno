package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	unstakingFee = uint64(100) // 1%
)

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
		transferByRegisterCall(tokenPath, consts.PROTOCOL_FEE_ADDR, feeAmount)

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

func SetUnstakingFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"reward_fee.gno__SetUnstakingFeeByAdmin() || only admin(%s) can set unstaking fee, called from %s",
				consts.ADMIN,
				caller,
			),
		))
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
