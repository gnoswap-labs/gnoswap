package consts

import (
	"std"
)

// GNOSWAP SERVICE
const (
	GNOSWAP_ADMIN std.Address = "g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq" // GSA
	DEV_OPS       std.Address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9" // DevOps

	TOKEN_REGISTER std.Address = "g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5"

	BLOCK_GENERATION_INTERVAL int64 = 5 // 5 seconds
)

// WRAP & UNWRAP
const (
	GNOT           string = "gnot"
	WRAPPED_WUGNOT string = "gno.land/r/demo/wugnot"

	UGNOT_MINT_DEPOSIT_TO_WRAP uint64 = 1000 // defined in gno.land/r/demo/wugnot
)

// CONTRACT PATH & ADDRESS
const (
	POOL_PATH string      = "gno.land/r/demo/pool"
	POOL_ADDR std.Address = "g15z32w7txv6lw259xzhzzmwtwmcjjc0m6dqzh6f"

	POSITION_PATH string      = "gno.land/r/demo/position"
	POSITION_ADDR std.Address = "g10wwa53xgu4397kvzz7akxar9370zjdpwux5th9"

	STAKER_PATH string      = "gno.land/r/demo/staker"
	STAKER_ADDR std.Address = "g1puv9dz470prjshjm9qyg25dyfvrgph2kvjph68"

	ROUTER_PATH string      = "gno.land/r/demo/router"
	ROUTER_ADDR std.Address = "g1pjtpgjpsn4hjfv2n4mpz8cczdn32jkpsqwxuav"

	GOV_PATH string      = "gno.land/r/demo/gov"
	GOV_ADDR std.Address = "g1kmat25auuqf0h5qvd4q7s707r8let5sky4tr76"

	GNS_PATH string      = "gno.land/r/demo/gns"
	GNS_ADDR std.Address = "g1zs77uvf8mxzq5k6lu2g8l8fzm6fvf79zkp6cgg"

	GNFT_PATH string      = "gno.land/r/demo/gnft"
	GNFT_ADDR std.Address = "g1mpsh77gemyy7ku2hu40c4t4w0ntegp4rg6m4cr"

	WUGNOT_PATH string      = "gno.land/r/demo/wugnot"
	WUGNOT_ADDR std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	EMISSION_PATH string      = "gno.land/r/demo/emission"
	EMISSION_ADDR std.Address = "g1znut3752hsmu227rat7zajkc2mswdjf08egtqu"

	PROTOCOL_FEE_PATH string      = "gno.land/r/demo/protocol_fee"
	PROTOCOL_FEE_ADDR std.Address = "g1k2v8szkm0pwzck5glat48p5adg7x9d98mfna4d"

	COMMUNITY_POOL_PATH string      = "gno.land/r/demo/community_pool"
	COMMUNITY_POOL_ADDR std.Address = "g165h7r5rcxl09z5y0yqzum4ghgaphulw4m59z2h"

	X_GNS_PATH string      = "gno.land/r/demo/x_gns"
	X_GNS_ADDR std.Address = "g1n38up35jsr260qcnq5a4z7d948s7ppepjw5wzc"
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
