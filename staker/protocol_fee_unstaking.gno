package staker

import (
	"std"

	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gns"
)

var (
	unstakingFee = uint64(100) // 1%
)

func handleUnstakingFee(
	tokenPath string,
	amount uint64,
	internal bool,
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
	} else {
		// external contract has fee
		ok := transferByRegisterCall(tokenPath, consts.PROTOCOL_FEE_ADDR, feeAmount)
		if !ok {
			panic(ufmt.Sprintf("[STAKER] reward_fee.gno__handleUnstakingFee() || expected transferByRegisterCall(%s, %s, %s) == true", tokenPath, consts.PROTOCOL_FEE_ADDR, u256.NewUint(feeAmount).ToString()))
		}
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", "INDIRECT",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenPath", tokenPath,
		"p_internal", boolToStr(internal),
		"feeAmount", uint64ToStr(feeAmount),
	)

	return amount - feeAmount
}

func GetUnstakingFee() uint64 {
	return unstakingFee
}

func SetUnstakingFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] protocol_fee_unstaking.gno__SetUnstakingFee() || only admin(%s) or governance(%s) can set unstaking fee, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	// 10000 (bps) = 100%
	if fee > 10000 {
		panic(ufmt.Sprintf("[STAKER] reward_fee.gno__SetUnstakingFee() || fee(%d) must be in range 0 ~ 10000", fee))
	}

	unstakingFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
