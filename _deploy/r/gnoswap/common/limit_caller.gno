package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	limitCaller bool = true
)

func GetLimitCaller() bool {
	return limitCaller
}

func SetLimitCaller(v bool) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("limit_caller.gno__SetLimitCaller() || only admin(%s) can set limit caller, called from %s", consts.ADMIN, caller),
		))
	}
	limitCaller = v
}
