package position

import (
	"std"
	"gno.land/r/demo/users"
)

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}