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
	IsHalted()

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic("only admin can set limitCaller")
	}
	limitCaller = v
}

func DisallowCallFromUser() {
	prevRealmPath := std.PrevRealm().PkgPath()
	if prevRealmPath == "" {
		panic("must be called by realm, not user")
	}
}

func AllowCallFromOnly(allowPath string) {
	if !limitCaller {
		prevPath := std.PrevRealm().PkgPath()

		if prevPath != allowPath {
			panic("caller is not allowed to call this function")
		}
	}
}
