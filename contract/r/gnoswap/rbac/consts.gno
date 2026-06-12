package rbac

// Initial addresses for protocol roles.
const (
	// ADMIN is the initial admin address for RBAC management.
	ADMIN address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"

	// DEV_OPS is the initial DevOps address for operational tasks.
	DEV_OPS address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"

	// EMISSION_ADDR is the derived address for the emission package.
	// EMISSION_ADDR is chain.PackageAddress("gno.land/r/gnoswap/emission")
	EMISSION_ADDR address = "g177jkk4xx79uledh9xedqkq4ht4ef9t6amxwjeq"

	// POOL_ADDR is the derived address for the pool package.
	// POOL_ADDR is chain.PackageAddress("gno.land/r/gnoswap/pool")
	POOL_ADDR address = "g1dexaf6aqkkyr9yfy9d5up69lsn7ra80af34g5v"

	// POSITION_ADDR is the derived address for the position package.
	// POSITION_ADDR is chain.PackageAddress("gno.land/r/gnoswap/position")
	POSITION_ADDR address = "g1y3uyaa63sjxvah2cx3c2usavwvx97kl8m2v7ye"

	// ROUTER_ADDR is the derived address for the router package.
	// ROUTER_ADDR is chain.PackageAddress("gno.land/r/gnoswap/router")
	ROUTER_ADDR address = "g1vc883gshu5z7ytk5cdynhc8c2dh67pdp4cszkp"

	// STAKER_ADDR is the derived address for the staker package.
	// STAKER_ADDR is chain.PackageAddress("gno.land/r/gnoswap/staker")
	STAKER_ADDR address = "g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3"

	// PROTOCOL_FEE_ADDR is the derived address for the protocol fee package.
	// PROTOCOL_FEE_ADDR is chain.PackageAddress("gno.land/r/gnoswap/protocol_fee")
	PROTOCOL_FEE_ADDR address = "g1r340tuven27z8wq50u8d20eqrsj470082682tp"

	// COMMUNITY_POOL_ADDR is the derived address for the community pool package.
	// COMMUNITY_POOL_ADDR is chain.PackageAddress("gno.land/r/gnoswap/community_pool")
	COMMUNITY_POOL_ADDR address = "g13lpjmjhl2du7whed3wxe4n5508txxja6ezxeg7"

	// GOV_GOVERNANCE_ADDR is the derived address for the governance package.
	// GOV_GOVERNANCE_ADDR is chain.PackageAddress("gno.land/r/gnoswap/gov/governance")
	GOV_GOVERNANCE_ADDR address = "g109hw2sc704c2vnxy2y89vjyqluvzra8rhp4l8w"

	// GOV_STAKER_ADDR is the derived address for the governance staker package.
	// GOV_STAKER_ADDR is chain.PackageAddress("gno.land/r/gnoswap/gov/staker")
	GOV_STAKER_ADDR address = "g1em9s40nfrwd2aqn9ypjv7d9x9z9c8uk5uxrza9"

	// GOV_XGNS_ADDR is the derived address for the xGNS governance package.
	// GOV_XGNS_ADDR is chain.PackageAddress("gno.land/r/gnoswap/gov/xgns")
	GOV_XGNS_ADDR address = "g1vfgdch449480u52q9g824rpx62hm5ahazkh0vp"

	// LAUNCHPAD_ADDR is the derived address for the launchpad package.
	// LAUNCHPAD_ADDR is chain.PackageAddress("gno.land/r/gnoswap/launchpad")
	LAUNCHPAD_ADDR address = "g1x6r75sxlkp9zfqufew0vcuq9sfclsq8uaqkru9"
)
