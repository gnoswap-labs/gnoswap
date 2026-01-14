package v1

import (
	"chain"
)

var (
	poolAddr        = chain.PackageAddress("gno.land/r/gnoswap/pool")
	routerAddr      = chain.PackageAddress("gno.land/r/gnoswap/router")
	positionAddr    = chain.PackageAddress("gno.land/r/gnoswap/position")
	protocolFeeAddr = chain.PackageAddress("gno.land/r/gnoswap/protocol_fee")

	routerV1Addr = chain.PackageAddress("gno.land/r/gnoswap/router/v3")
)
