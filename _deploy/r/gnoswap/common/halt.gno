package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	halted bool = false
)

func GetHalt() bool {
	return halted
}

func IsHalted() {
	if halted {
		panic("[COMMON] halt.gno__IsHalted() || gnoswap halted")
	}
}

// SetHaltByAdmin sets the halt status.
// Panics if the caller is not the admin.
func SetHaltByAdmin(halt bool) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(
			ufmt.Sprintf(
				"[COMMON] halt.gno__SetHaltByAdmin() || only admin(%s) can set halt, called from %s",
				consts.ADMIN,
				caller,
			),
		)
	}

	setHalt(halt)

	prevAddr, prevRealm := getPrev()
	if halt {
		std.Emit(
			"SetHaltByAdmin",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", boolToStr(halt),
		)
	} else {
		std.Emit(
			"UnsetHaltByAdmin",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", boolToStr(halt),
		)
	}
}

// SetHalt sets the halt status.
// Panics if the caller is not the governance contract.
func SetHalt(halt bool) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[COMMON] halt.gno__SetHalt() || only governance(%s) can set halt, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setHalt(halt)

	prevAddr, prevRealm := getPrev()
	if halt {
		std.Emit(
			"SetHalt",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", boolToStr(halt),
		)
	} else {
		std.Emit(
			"UnsetHalt",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"halt", boolToStr(halt),
		)
	}
}

func setHalt(halt bool) {
	halted = halt
}
