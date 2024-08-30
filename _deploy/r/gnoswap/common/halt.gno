package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	halt bool = false
)

func GetHalt() bool {
	return halt
}

func IsHalted() {
	if halt {
		panic("[COMMON] halt.gno__IsHalted() || gnoswap halted")
	}
}

func SetHalt(v bool) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[COMMON] halt.gno__SetHalt() || only admin(%s) or governance(%s) can set halt, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	halt = v
}
