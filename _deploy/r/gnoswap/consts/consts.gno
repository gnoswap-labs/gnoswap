package consts

import (
	"std"
)

// GNOSWAP SERVICE
const (
	GNOSWAP_ADMIN std.Address = "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c" // GSA
	DEV_OPS       std.Address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9" // DevOps

	TOKEN_REGISTER std.Address = "g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5"

	BLOCK_GENERATION_INTERVAL int64 = 2 // 2 seconds
)

// WRAP & UNWRAP
const (
	GNOT           string = "gnot"
	WRAPPED_WUGNOT string = "gno.land/r/demo/wugnot"

	UGNOT_MINT_DEPOSIT_TO_WRAP uint64 = 1000 // defined in gno.land/r/demo/wugnot
)

// CONTRACT PATH & ADDRESS
const (
	POOL_PATH string      = "gno.land/r/gnoswap/pool"
	POOL_ADDR std.Address = "g1dexaf6aqkkyr9yfy9d5up69lsn7ra80af34g5v"

	POSITION_PATH string      = "gno.land/r/gnoswap/position"
	POSITION_ADDR std.Address = "g1y3uyaa63sjxvah2cx3c2usavwvx97kl8m2v7ye"

	ROUTER_PATH string      = "gno.land/r/gnoswap/router"
	ROUTER_ADDR std.Address = "g1vc883gshu5z7ytk5cdynhc8c2dh67pdp4cszkp"

	STAKER_PATH string      = "gno.land/r/gnoswap/staker"
	STAKER_ADDR std.Address = "g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3"

	GOV_PATH string      = "gno.land/r/gnoswap/gov"
	GOV_ADDR std.Address = "g1egdt2l7xjcrm6qjwyd3g60z6e9cnr75pmcuasc"

	GNS_PATH string      = "gno.land/r/gnoswap/gns"
	GNS_ADDR std.Address = "g13ffa5r3mqfxu3s7ejl02scq9536wt6c2t789dm"

	GNFT_PATH string      = "gno.land/r/gnoswap/gnft"
	GNFT_ADDR std.Address = "g1mclfz2dn4lnez0lcjwgz67hh72rdafjmufvfmw"

	WUGNOT_PATH string      = "gno.land/r/demo/wugnot"
	WUGNOT_ADDR std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	EMISSION_PATH string      = "gno.land/r/gnoswap/emission"
	EMISSION_ADDR std.Address = "g177jkk4xx79uledh9xedqkq4ht4ef9t6amxwjeq"

	PROTOCOL_FEE_PATH string      = "gno.land/r/gnoswap/protocol_fee"
	PROTOCOL_FEE_ADDR std.Address = "g1r340tuven27z8wq50u8d20eqrsj470082682tp"

	COMMUNITY_POOL_PATH string      = "gno.land/r/gnoswap/community_pool"
	COMMUNITY_POOL_ADDR std.Address = "g13lpjmjhl2du7whed3wxe4n5508txxja6ezxeg7"

	X_GNS_PATH string      = "gno.land/r/gnoswap/x_gns"
	X_GNS_ADDR std.Address = "g1gea2eevsk8r5qfu683kajv5nnkpscvpxuchr4q"
)

// NUMBER
const (
	// calculated by https://mathiasbynens.be/demo/integer-range
	MAX_UINT8 string = "255"
	UINT8_MAX uint8  = 255

	MAX_UINT16 string = "65535"
	UINT16_MAX uint16 = 65535

	MAX_UINT32 string = "4294967295"
	UINT32_MAX uint32 = 4294967295

	MAX_UINT64 string = "18446744073709551615"
	UINT64_MAX uint64 = 18446744073709551615

	MAX_UINT128 string = "340282366920938463463374607431768211455"

	MAX_UINT160 string = "1461501637330902918203684832716283019655932542975"

	MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

	// Tick Related
	MIN_TICK int32 = -887272
	MAX_TICK int32 = 887272

	MIN_SQRT_RATIO string = "4295128739"                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342" // same as TickMathGetSqrtRatioAtTick(MAX_TICK)

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1

	// ETC
	Q64  string = "18446744073709551616"                    // 2 ** 64
	Q96  string = "79228162514264337593543950336"           // 2 ** 96
	Q128 string = "340282366920938463463374607431768211456" // 2 ** 128

)

// ETCs
const (
	// REF: https://github.com/gnolang/gno/pull/2401#discussion_r1648064219
	ZERO_ADDRESS std.Address = "g100000000000000000000000000000000dnmcnx"
)
