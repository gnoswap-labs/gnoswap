package emission

import (
	"std"

	"gno.land/r/gnoswap/consts"
	"gno.land/r/gnoswap/gns"
)

var emissionAddr std.Address = consts.EMISSION_ADDR

// mintGns mints GNS to emission address
func mintGns() {
	gns.Mint(a2u(emissionAddr))
}
