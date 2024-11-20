package emission

import (
	"std"

	pusers "gno.land/p/demo/users"
	"gno.land/r/gnoswap/v1/gns"
)

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func gnsBalance(addr std.Address) uint64 {
	a2u := pusers.AddressOrName(addr)

	return gns.BalanceOf(a2u)
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}
