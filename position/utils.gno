package position

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
)

func checkDeadline(deadline int64) {
	now := time.Now().Unix()
	if now > deadline {
		panic(addDetailToError(
			errExpired,
			ufmt.Sprintf("utils.gno__checkDeadline() || transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// assertOnlyValidAddress panics if the address is invalid.
func assertOnlyValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s)", addr),
		))
	}
}
