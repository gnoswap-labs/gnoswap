package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
)

var warmUp = make(map[int64]int64) // map[percent]block

func init() {
	warmUp[100] = 1296001 // 30d ~
	warmUp[70] = 432001   // 10d ~ 30d
	warmUp[50] = 216001   // 5d ~ 10d
	warmUp[30] = 1        // ~ 5d
}

func GetWarmUp(percent int64) int64 {
	value, exist := warmUp[percent]
	if !exist {
		panic(addDetailToError(errDataNotFound,
			ufmt.Sprintf("warm_up.gno__GetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	return value
}

func SetWarmUpByAdmin(percent int64, block int64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(errNoPermission,
			ufmt.Sprintf("warm_up.gno__SetWarmUpByAdmin() || only admin(%s) can set warm up period, called from %s", consts.ADMIN, caller),
		))
	}

	setWarmUp(percent, block)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetWarmUpByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"percent", ufmt.Sprintf("%d", percent),
		"block", ufmt.Sprintf("%d", block),
	)
}

func SetWarmUp(percent int64, block int64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(errNoPermission,
			ufmt.Sprintf("warm_up.gno__SetWarmUp() || only governance(%s) can set warm up period, called from %s", consts.GOV_GOVERNANCE_ADDR, caller),
		))
	}

	setWarmUp(percent, block)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetWarmUp",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"percent", ufmt.Sprintf("%d", percent),
		"block", ufmt.Sprintf("%d", block),
	)
}

func setWarmUp(percent int64, block int64) {
	if _, exist := warmUp[percent]; !exist {
		panic(addDetailToError(errDataNotFound,
			ufmt.Sprintf("warm_up.gno__setWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	warmUp[percent] = block
}
