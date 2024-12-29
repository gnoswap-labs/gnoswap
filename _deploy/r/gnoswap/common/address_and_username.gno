package common

import (
	"std"

	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
)

// AddrToUser converts a type from address to AddressOrName.
// It panics if the address is invalid.
func AddrToUser(addr std.Address) pusers.AddressOrName {
	assertValidAddr(addr)
	return pusers.AddressOrName(addr)
}

// UserToAddr converts a type from AddressOrName to address.
// by resolving the user through the users realms.
func UserToAddr(user pusers.AddressOrName) std.Address {
	return users.Resolve(user)
}

// assertValidAddr checks if the given address is valid.
// It panics with a detailed error message if the address is invalid.
func assertValidAddr(addr std.Address) {
	if !addr.IsValid() {
		panic(newErrorWithDetail(errInvalidAddr, addr.String()))
	}
}
