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
	MustCallFromAdmin()
	limitCaller = v
}

func MustCallFromAdmin() {
	caller := std.GetOrigCaller()
	if caller != consts.GNOSWAP_ADMIN {
		panic("must be called by admin")
	}
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
