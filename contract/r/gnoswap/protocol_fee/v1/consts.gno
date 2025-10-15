package v1

import (
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var (
	protocolFeeAddr = access.MustGetAddressWithVersion(prabc.ROLE_PROTOCOL_FEE.String(), 1)
	govStakerAddr   = access.MustGetAddressWithVersion(prabc.ROLE_GOV_STAKER.String(), 1)
	devOpsAddr      = access.MustGetAddressWithVersion(prabc.ROLE_DEVOPS.String(), 1)
)
