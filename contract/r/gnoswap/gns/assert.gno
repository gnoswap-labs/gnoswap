package gns

import (
	"chain/runtime"

	"gno.land/p/nt/ufmt"
)

func assertAddressIsPreviousRealm(addr address) {
	previousRealm := runtime.PreviousRealm()
	if addr != previousRealm.Address() {
		panic(ufmt.Errorf("address(%s) is not previous realm", addr.String()))
	}
}
