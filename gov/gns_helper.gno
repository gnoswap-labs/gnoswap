package gov

import (
	"std"

	gns "gno.land/r/demo/gns"

	pusers "gno.land/p/demo/users"
)

func balanceOf(address std.Address) uint64 {
	return gns.BalanceOf(a2u(address))
}

func transfer(to std.Address, amount uint64) {
	gns.Transfer(a2u(to), amount)
}

func a2u(address std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(address)
}
