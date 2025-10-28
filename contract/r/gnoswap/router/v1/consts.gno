package v1

import (
	"chain"
)

const (
	maxApprove = int64(9223372036854775807)

	zeroString          = "0"
	maxPercentageString = "100"
)

var (
	poolAddr        = chain.PackageAddress("gno.land/r/gnoswap/pool")
	routerAddr      = chain.PackageAddress("gno.land/r/gnoswap/router")
	positionAddr    = chain.PackageAddress("gno.land/r/gnoswap/position")
	protocolFeeAddr = chain.PackageAddress("gno.land/r/gnoswap/protocol_fee")
)
