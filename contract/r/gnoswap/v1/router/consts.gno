package router

import (
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

const maxApprove int64 = 9223372036854775807

var (
	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
)
