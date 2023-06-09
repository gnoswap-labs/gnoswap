package liquidity

import (
	"gno.land/r/demo/users"
	"std"
)

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func a2aon(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}
