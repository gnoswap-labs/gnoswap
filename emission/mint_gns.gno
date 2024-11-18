package emission

import (
	"std"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v2/consts"
)

var emissionAddr std.Address = consts.EMISSION_ADDR

// mintGns mints GNS to emission address
func mintGns() uint64 {
	return gns.Mint(a2u(emissionAddr))
}
