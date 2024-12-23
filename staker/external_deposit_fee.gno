package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

var (
	depositGnsAmount = uint64(1_000_000_000) // 1_000 GNS
)

func GetDepositGnsAmount() uint64 {
	return depositGnsAmount
}

func SetDepositGnsAmountByAdmin(amount uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
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

// SetDepositGnsAmount modifies the deposit gns amount
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/staker/external_deposit_fee.gno
func SetDepositGnsAmount(amount uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
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
