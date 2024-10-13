package staker

import (
	"std"
	"strconv"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/gns"
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

	if internal {
		// staker contract has fee
		gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), feeAmount)
		std.Emit(
			"ProtocolFeeInternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_lpTokenId", strconv.FormatUint(tokenId, 10),
			"internal_poolPath", poolPath,
			"internal_token", consts.GNS_PATH,
			"internal_amount", strconv.FormatUint(feeAmount, 10),
		)

	} else {
		// external contract has fee
		ok := transferByRegisterCall(tokenPath, consts.PROTOCOL_FEE_ADDR, feeAmount)
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__handleUnstakingFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.PROTOCOL_FEE_ADDR, u256.NewUint(feeAmount).ToString()))
		}
		std.Emit(
			"ProtocolFeeExternalReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_lpTokenId", strconv.FormatUint(tokenId, 10),
			"internal_poolPath", poolPath,
			"internal_token", tokenPath,
			"internal_amount", strconv.FormatUint(feeAmount, 10),
		)
	}

	return amount - feeAmount
}

func GetUnstakingFee() uint64 {
	return unstakingFee
}

func SetUnstakingFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic(
			ufmt.Sprintf(
				"[STAKER] reward_fee.gno__SetUnstakingFeeByAdmin() || only admin(%s) can set unstaking fee, called from %s",
				consts.GNOSWAP_ADMIN,
				caller,
			),
		)
	}

	setUnstakingFee(fee)

	std.Emit(
		"SetUnstakingFeeByAdmin",
		"fee", uint64ToStr(fee),
	)
}

func SetUnstakingFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] reward_fee.gno__SetUnstakingFee() || only governance(%s) can set unstaking fee, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setUnstakingFee(fee)

	std.Emit(
		"SetUnstakingFee",
		"fee", uint64ToStr(fee),
	)
}

func setUnstakingFee(fee uint64) {
	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetUnstakingFee() || fee(%d) must be in range 0 ~ 10000", fee))
	}

	unstakingFee = fee
}
