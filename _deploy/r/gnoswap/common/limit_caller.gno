package common

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
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
		panic("must be called by admin")
	}
	limitCaller = v
}
