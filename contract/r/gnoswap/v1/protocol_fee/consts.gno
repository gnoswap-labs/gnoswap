package protocol_fee

import (
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var (
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prabc.ROLE_GOV_STAKER.String())
	devOpsAddr, _      = access.GetAddress(prabc.ROLE_DEVOPS.String())
)
