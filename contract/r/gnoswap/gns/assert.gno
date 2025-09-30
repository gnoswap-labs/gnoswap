package gns

import (
	"std"

	"gno.land/p/nt/ufmt"
)

func assertAddressIsPreviousRealm(addr std.Address) {
	previousRealm := std.PreviousRealm()
	if addr != previousRealm.Address() {
		panic(ufmt.Errorf("address(%s) is not previous realm", addr.String()))
	}
}
