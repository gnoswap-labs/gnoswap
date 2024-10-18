package protocol_fee

import (
	"std"
)

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func assertUserCall() {
	if !isUserCall() {
		panic(addDetailToError(errNoPermission, "protocol_fee.gno__assertUserCall() || must be called by user"))
	}
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}
