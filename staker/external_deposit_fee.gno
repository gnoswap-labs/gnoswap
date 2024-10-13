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

func SetDepositGnsAmountByAdmin(amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic(
			ufmt.Sprintf(
				"[STAKER] external_deposit_fee.gno__SetDepositGnsAmountByAdmin() || only admin(%s) can set deposit gns amount, called from %s",
				consts.GNOSWAP_ADMIN,
				caller,
			),
		)
	}

	setDepositGnsAmount(amount)

	std.Emit(
		"SetDepositGnsAmountByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"amount", uint64ToStr(amount),
	)
}

func SetDepositGnsAmount(amount uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] external_deposit_fee.gno__SetDepositGnsAmount() || only governance(%s) can set deposit gns amount, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setDepositGnsAmount(amount)

	std.Emit(
		"SetDepositGnsAmount",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"amount", uint64ToStr(amount),
	)
}

func setDepositGnsAmount(amount uint64) {
	depositGnsAmount = amount
}
