package rbac

import (
	"std"

	prbac "gno.land/p/gnoswap/rbac"
)

// DefaultRoleAddresses maps system roles to their default addresses.
// Used during RBAC initialization to set up the protocol role structure.
var DefaultRoleAddresses = map[prbac.SystemRole]std.Address{
	prbac.ROLE_ADMIN:          ADMIN,
	prbac.ROLE_DEVOPS:         DEV_OPS,
	prbac.ROLE_COMMUNITY_POOL: COMMUNITY_POOL_ADDR,
	prbac.ROLE_GOVERNANCE:     GOV_GOVERNANCE_ADDR,
	prbac.ROLE_GOV_STAKER:     GOV_STAKER_ADDR,
	prbac.ROLE_XGNS:           GOV_XGNS_ADDR,
	prbac.ROLE_POOL:           POOL_ADDR,
	prbac.ROLE_POSITION:       POSITION_ADDR,
	prbac.ROLE_ROUTER:         ROUTER_ADDR,
	prbac.ROLE_STAKER:         STAKER_ADDR,
	prbac.ROLE_EMISSION:       EMISSION_ADDR,
	prbac.ROLE_LAUNCHPAD:      LAUNCHPAD_ADDR,
	prbac.ROLE_PROTOCOL_FEE:   PROTOCOL_FEE_ADDR,
}
