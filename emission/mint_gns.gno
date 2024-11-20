package emission

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

var emissionAddr std.Address = consts.EMISSION_ADDR

// mintGns mints GNS to emission address
func mintGns() uint64 {
	return gns.Mint(a2u(emissionAddr))
}
