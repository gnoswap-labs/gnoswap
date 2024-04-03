package pool

import (
	"std"

	pusers "gno.land/p/demo/users"

	u256 "gno.land/p/demo/gnoswap/uint256"
)

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func u256Min(num1, num2 *u256.Uint) *u256.Uint {
	if num1.Lt(num2) {
		return num1
	}

	return num2
}
