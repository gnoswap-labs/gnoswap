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
	if caller != consts.ADMIN {
		panic(
			ufmt.Sprintf(
				"[STAKER] external_deposit_fee.gno__SetDepositGnsAmountByAdmin() || only admin(%s) can set deposit gns amount, called from %s",
				consts.ADMIN,
				caller,
			),
		)
	}

	setDepositGnsAmount(amount)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetDepositGnsAmountByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"amount", ufmt.Sprintf("%d", amount),
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

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetDepositGnsAmount",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"amount", ufmt.Sprintf("%d", amount),
	)
}

func setDepositGnsAmount(amount uint64) {
	depositGnsAmount = amount
}
