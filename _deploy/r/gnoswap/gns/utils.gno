package gns

import (
	"std"

	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
)

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func assertShouldNotBeHalted() {
	common.IsHalted()
}

func assertCallerIsEmission() {
	caller := std.PrevRealm().Addr()
	if err := common.EmissionOnly(caller); err != nil {
		panic(err)
	}
}
