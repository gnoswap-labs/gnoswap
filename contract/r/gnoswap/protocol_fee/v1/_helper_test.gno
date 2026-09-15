package protocol_fee

import (
	prabc "gno.land/p/gnoswap/rbac/v1"
	"gno.land/r/gnoswap/access/v1"
)

var (
	protocolFeeAddr = access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	devOpsAddr      = access.MustGetAddress(prabc.ROLE_DEVOPS.String())
	govStakerAddr   = access.MustGetAddress(prabc.ROLE_GOV_STAKER.String())
)
