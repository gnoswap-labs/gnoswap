package v1

import (
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var (
	protocolFeeAddr = access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	devOpsAddr      = access.MustGetAddress(prabc.ROLE_DEVOPS.String())
	govStakerAddr   = access.MustGetAddress(prabc.ROLE_GOV_STAKER.String())
)
