package gov

import (
	"std"

	gns "gno.land/r/demo/gns"

	"gno.land/r/demo/users"
)

func balanceOf(address std.Address) uint64 {
	return gns.BalanceOf(users.AddressOrName(address))
}

func transfer(to std.Address, amount uint64) {
	gns.Transfer(users.AddressOrName(to), amount)
}

func mint(recipient std.Address, amount uint64) {
	gns.Mint(users.AddressOrName(recipient), amount)
}
