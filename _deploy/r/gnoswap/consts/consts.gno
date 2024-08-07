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

	UGNOT_MIN_DEPOSIT_TO_WRAP uint64 = 1000 // defined in gno.land/r/demo/wugnot
)

// CONTRACT PATH & ADDRESS
const (
	POOL_PATH string      = "gno.land/r/gnoswap/v2/pool"
	POOL_ADDR std.Address = "g126swhfaq2vyvvjywevhgw7lv9hg8qan93dasu8"

	POSITION_PATH string      = "gno.land/r/gnoswap/v2/position"
	POSITION_ADDR std.Address = "g1vsm68lq9cpn7x507s6gh59anmx86kxfhzyszu2"

	ROUTER_PATH string      = "gno.land/r/gnoswap/v2/router"
	ROUTER_ADDR std.Address = "g1cnz5gm2l09pm2k6rknjjar9a2w53fdhk4yjzy5"

	STAKER_PATH string      = "gno.land/r/gnoswap/v2/staker"
	STAKER_ADDR std.Address = "g14fclvfqynndp0l6kpyxkpgn4sljw9rr96hz46l"

	GOV_PATH string      = "gno.land/r/gnoswap/v2/gov"
	GOV_ADDR std.Address = "g1cu4dufdlzu0l9pekkqhw6mjnrxkp3z7ykst09d"

	GNS_PATH string      = "gno.land/r/gnoswap/v2/gns"
	GNS_ADDR std.Address = "g1ttcyeq0u5f6npysfxvew7tzucvwqy0qjp04p95"

	GNFT_PATH string      = "gno.land/r/gnoswap/v2/gnft"
	GNFT_ADDR std.Address = "g1rn4pederer0qlw2f7k72ddywde6pv3v3vl69nc"

	WUGNOT_PATH string      = "gno.land/r/demo/wugnot"
	WUGNOT_ADDR std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	EMISSION_PATH string      = "gno.land/r/gnoswap/v2/emission"
	EMISSION_ADDR std.Address = "g1mfvpsj55gssep3wkt2t04d6dc3yfs9py5qquft"

	PROTOCOL_FEE_PATH string      = "gno.land/r/gnoswap/v2/protocol_fee"
	PROTOCOL_FEE_ADDR std.Address = "g1397dea8xlfv5858xzhsly7k998xm2zlvrm93t2"

	COMMUNITY_POOL_PATH string      = "gno.land/r/gnoswap/v2/community_pool"
	COMMUNITY_POOL_ADDR std.Address = "g1r79m0scwztcdvk3c6sy4rjrtv3rnnzrs9ddh9w"

	X_GNS_PATH string      = "gno.land/r/gnoswap/v2/x_gns"
	X_GNS_ADDR std.Address = "g1dd0t56nqh5a468chr7vkgp5ftzmquvpja5l7qh"
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
