package router

import (
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

var (
	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
)
