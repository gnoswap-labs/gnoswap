package emission

import (
	"std"

	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/gnoswap/consts"
	"gno.land/r/demo/gns"
)

var emissionAddr std.Address = consts.EMISSION_ADDR

func EmitGns() {
	gns.Mint(a2u(emissionAddr))
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
