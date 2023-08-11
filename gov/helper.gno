package gov

import (
	"std"

	gnos "gno.land/r/gnos"

	"gno.land/r/demo/users"
)

func balanceOf(address std.Address) uint64 {
	return gnos.BalanceOf(users.AddressOrName(address))
}

func transfer(to std.Address, amount uint64) {
	gnos.Transfer(users.AddressOrName(to), amount)
}

func mint(recipient std.Address, amount uint64) {
	gnos.Mint(users.AddressOrName(recipient), amount)
}