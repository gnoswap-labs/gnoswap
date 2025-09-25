package router

import (
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

const (
	maxApprove = int64(9223372036854775807)

	zeroString          = "0"
	maxPercentageString = "100"
)

var (
	poolAddr        = access.MustGetAddressWithVersion(prabc.ROLE_POOL.String(), 1)
	routerAddr      = access.MustGetAddressWithVersion(prabc.ROLE_ROUTER.String(), 1)
	positionAddr    = access.MustGetAddressWithVersion(prabc.ROLE_POSITION.String(), 1)
	protocolFeeAddr = access.MustGetAddressWithVersion(prabc.ROLE_PROTOCOL_FEE.String(), 1)
)
