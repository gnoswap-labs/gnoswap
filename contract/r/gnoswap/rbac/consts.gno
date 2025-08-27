package rbac

import "std"

// Initial addresses for protocol roles.
const (
	// ADMIN is the initial admin address for RBAC management.
	ADMIN std.Address = "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"
	// DEV_OPS is the initial DevOps address for operational tasks.
	DEV_OPS std.Address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"
)

// Derived addresses for GnoSwap protocol packages.
var (
	// GNS_ADDR is the derived address for the GNS token package.
	GNS_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/gns")
	// EMISSION_ADDR is the derived address for the emission package.
	EMISSION_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/emission")

	// POOL_ADDR is the derived address for the pool package.
	POOL_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/pool")
	// POSITION_ADDR is the derived address for the position package.
	POSITION_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/position")
	// ROUTER_ADDR is the derived address for the router package.
	ROUTER_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/router")
	// STAKER_ADDR is the derived address for the staker package.
	STAKER_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/staker")
	// PROTOCOL_FEE_ADDR is the derived address for the protocol fee package.
	PROTOCOL_FEE_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/protocol_fee")
	// COMMUNITY_POOL_ADDR is the derived address for the community pool package.
	COMMUNITY_POOL_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/community_pool")
	// GOV_GOVERNANCE_ADDR is the derived address for the governance package.
	GOV_GOVERNANCE_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/governance")
	// GOV_STAKER_ADDR is the derived address for the governance staker package.
	GOV_STAKER_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/staker")
	// GOV_XGNS_ADDR is the derived address for the xGNS governance package.
	GOV_XGNS_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/xgns")
	// LAUNCHPAD_ADDR is the derived address for the launchpad package.
	LAUNCHPAD_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/launchpad")
)
