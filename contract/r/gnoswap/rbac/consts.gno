package rbac

import "std"

// initial addresses
const (
	ADMIN   std.Address = "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"
	DEV_OPS std.Address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"
)

var (
	GNS_ADDR      std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/gns")
	EMISSION_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/emission")

	POOL_ADDR           std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/pool")
	POSITION_ADDR       std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/position")
	ROUTER_ADDR         std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/router")
	STAKER_ADDR         std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/staker")
	PROTOCOL_FEE_ADDR   std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/protocol_fee")
	COMMUNITY_POOL_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/community_pool")
	GOV_GOVERNANCE_ADDR std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/governance")
	GOV_STAKER_ADDR     std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/staker")
	GOV_XGNS_ADDR       std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/gov/xgns")
	LAUNCHPAD_ADDR      std.Address = std.DerivePkgAddr("gno.land/r/gnoswap/v1/launchpad")
)
