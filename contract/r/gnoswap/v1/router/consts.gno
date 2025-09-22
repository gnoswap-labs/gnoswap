package router

import (
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

const maxApprove int64 = 9223372036854775807

var (
	poolAddr        = access.MustGetAddress(prabc.ROLE_POOL.String())
	routerAddr      = access.MustGetAddress(prabc.ROLE_ROUTER.String())
	positionAddr    = access.MustGetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr = access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
)
