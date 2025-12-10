package rbac

import "chain"

// Initial addresses for protocol roles.
const (
	// ADMIN is the initial admin address for RBAC management.
	ADMIN address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"
	// DEV_OPS is the initial DevOps address for operational tasks.
	DEV_OPS address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"
)

// Derived addresses for GnoSwap protocol packages.
var (
	// EMISSION_ADDR is the derived address for the emission package.
	EMISSION_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/emission")

	// POOL_ADDR is the derived address for the pool package.
	POOL_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/pool")
	// POSITION_ADDR is the derived address for the position package.
	POSITION_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/position")
	// ROUTER_ADDR is the derived address for the router package.
	ROUTER_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/router")
	// STAKER_ADDR is the derived address for the staker package.
	STAKER_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/staker")
	// PROTOCOL_FEE_ADDR is the derived address for the protocol fee package.
	PROTOCOL_FEE_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/protocol_fee")
	// COMMUNITY_POOL_ADDR is the derived address for the community pool package.
	COMMUNITY_POOL_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/community_pool")
	// GOV_GOVERNANCE_ADDR is the derived address for the governance package.
	GOV_GOVERNANCE_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/gov/governance")
	// GOV_STAKER_ADDR is the derived address for the governance staker package.
	GOV_STAKER_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/gov/staker")
	// GOV_XGNS_ADDR is the derived address for the xGNS governance package.
	GOV_XGNS_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/gov/xgns")
	// LAUNCHPAD_ADDR is the derived address for the launchpad package.
	LAUNCHPAD_ADDR address = chain.PackageAddress("gno.land/r/gnoswap/launchpad")
)
