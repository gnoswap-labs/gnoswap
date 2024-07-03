package emission

import (
	"std"

	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/gnoswap/consts"
	"gno.land/r/demo/gns"
)

// emissionAddr is the address from which GNS tokens will be emitted.
var emissionAddr std.Address = consts.EMISSION_ADDR

// EmitGns mints new GNS tokens to the emission address.
func EmitGns() {
	gns.Mint(a2u(emissionAddr))
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
