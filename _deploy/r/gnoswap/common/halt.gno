package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	halted bool = false
)

func GetHalt() bool {
	return halted
}

func IsHalted() {
	if halted {
		panic(addDetailToError(
			errHalted,
			"gnoswap halted",
		))
	}
}

// SetHaltByAdmin sets the halt status.
func SetHaltByAdmin(halt bool) {
	caller := std.PrevRealm().Addr()
	err := AdminOnly(caller)
	if err != nil {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"only admin(%s) can set halt, called from %s",
				consts.ADMIN,
				caller,
			),
		))
	}

	setHalt(halt)

	prevAddr, prevRealm := getPrev()
	if halt {
		std.Emit(
			"SetHaltByAdmin",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", ufmt.Sprintf("%t", halt),
		)
	} else {
		std.Emit(
			"UnsetHaltByAdmin",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", ufmt.Sprintf("%t", halt),
		)
	}
}

// SetHalt sets the halt status.
// Only governance contract can execute this function via proposal
func SetHalt(halt bool) {
	caller := std.PrevRealm().Addr()
	err := GovernanceOnly(caller)
	if err != nil {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"only governance(%s) can set halt, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		))
	}

	setHalt(halt)

	prevAddr, prevRealm := getPrev()
	if halt {
		std.Emit(
			"SetHalt",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", ufmt.Sprintf("%t", halt),
		)
	} else {
		std.Emit(
			"UnsetHalt",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", ufmt.Sprintf("%t", halt),
		)
	}
}

func setHalt(halt bool) {
	halted = halt
}
