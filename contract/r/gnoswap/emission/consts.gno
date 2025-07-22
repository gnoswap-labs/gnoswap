package emission

import (
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

var (
	adminAddr, _         = access.GetAddress(prabc.ROLE_ADMIN.String())
	stakerAddr, _        = access.GetAddress(prabc.ROLE_STAKER.String())
	govStakerAddr, _     = access.GetAddress(prabc.ROLE_GOV_STAKER.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())
	emissionAddr, _      = access.GetAddress(prabc.ROLE_EMISSION.String())
	devOpsAddr, _        = access.GetAddress(prabc.ROLE_DEVOPS.String())
)
