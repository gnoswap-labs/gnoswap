package rbac

import "chain"

// User-controlled addresses for protocol roles.
const (
	// ADMIN is the initial admin address for RBAC management.
	ADMIN address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"

	// DEV_OPS is the initial DevOps address for operational tasks.
	DEV_OPS address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"
)

// Derived package addresses — computed deterministically from deployment paths
// so they stay correct if packages are renamed or re-deployed.
var (
	EMISSION_ADDR     = chain.PackageAddress("gno.land/r/gnoswap/emission")
	POOL_ADDR         = chain.PackageAddress("gno.land/r/gnoswap/pool")
	POSITION_ADDR     = chain.PackageAddress("gno.land/r/gnoswap/position")
	ROUTER_ADDR       = chain.PackageAddress("gno.land/r/gnoswap/router")
	STAKER_ADDR       = chain.PackageAddress("gno.land/r/gnoswap/staker")
	PROTOCOL_FEE_ADDR = chain.PackageAddress("gno.land/r/gnoswap/protocol_fee")
	COMMUNITY_POOL_ADDR = chain.PackageAddress("gno.land/r/gnoswap/community_pool")
	GOV_GOVERNANCE_ADDR = chain.PackageAddress("gno.land/r/gnoswap/gov/governance")
	GOV_STAKER_ADDR     = chain.PackageAddress("gno.land/r/gnoswap/gov/staker")
	GOV_XGNS_ADDR       = chain.PackageAddress("gno.land/r/gnoswap/gov/xgns")
	LAUNCHPAD_ADDR      = chain.PackageAddress("gno.land/r/gnoswap/launchpad")
)
