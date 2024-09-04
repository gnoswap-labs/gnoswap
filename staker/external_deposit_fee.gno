package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	depositGnsAmount = uint64(1_000_000_000) // 1_000 GNS
)

func GetDepositGnsAmount() uint64 {
	return depositGnsAmount
}

func SetDepositGnsAmount(amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] external_deposit_fee.gno__SetDepositGnsAmount() || only admin(%s) or governance(%s) can set deposit gns amount, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	depositGnsAmount = amount

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_amount", uint64ToStr(amount),
	)
}
