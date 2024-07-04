package emission

import (
	"std"

	pusers "gno.land/p/demo/users"
)

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
