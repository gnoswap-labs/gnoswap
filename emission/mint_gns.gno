package emission

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"
)

var emissionAddr std.Address = consts.EMISSION_ADDR

// mintGns mints GNS to emission address
func mintGns() uint64 {
	return gns.Mint(a2u(emissionAddr))
}
