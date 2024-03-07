package consts

import (
	"std"
)

// MOST LIKELY FIXED, BUT CHANGABLE VIA GOVERNANCE
var (
	PROTOCOL_FEE_ROUTER uint64 = 15 // 0.15%
)

// GNOSWAP SERVICE
const (
	GNOSWAP_ADMIN std.Address = "g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4" // GSA, r3v4_xxx: CHANGE WHEN DEPLOYING TO OFFICIAL NETWORK
	FEE_COLLECTOR std.Address = "g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4" // SAME AS GSA FOR NOW, r3v4_xxx: CHANGE WHEN DEPLOYING TO OFFICIAL NETWORK

	INTERNAL_REWARD_ACCOUNT std.Address = "g1paqttvcjcluuya9n9twyw7yacv54mt7ld3gvzm" // IRA for GNS, r3v4_xxx: CHANGE WHEN DEPLOYING TO OFFICIAL NETWORK

	POOL_CREATION_FEE uint64 = 500_000_000
)

// WRAP & UNWRAP
const (
	GNOT           string = "gnot"
	WRAPPED_WUGNOT string = "gno.land/r/demo/wugnot"
)

// CONTRACT PATH & ADDRESS
const (
	POOL_PATH string      = "gno.land/r/demo/pool"
	POOL_ADDR std.Address = std.DerivePkgAddr(POOL_PATH)

	POSITION_PATH string      = "gno.land/r/demo/position"
	POSITION_ADDR std.Address = std.DerivePkgAddr(POSITION_PATH)

	STAKER_PATH string      = "gno.land/r/demo/staker"
	STAKER_ADDR std.Address = std.DerivePkgAddr(STAKER_PATH)

	ROUTER_ADDR std.Address = std.DerivePkgAddr(ROUTER_PATH)
	ROUTER_PATH string      = "gno.land/r/demo/router"

	GOV_PATH string      = "gno.land/r/demo/gov"
	GOV_ADDR std.Address = std.DerivePkgAddr(GOV_PATH)

	GNS_PATH string      = "gno.land/r/demo/gns"
	GNS_ADDR std.Address = std.DerivePkgAddr(GNS_PATH)

	GNFT_PATH string      = "gno.land/r/demo/gnft"
	GNFT_ADDR std.Address = std.DerivePkgAddr(GNFT_PATH)
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
	ZERO_ADDRESS std.Address = ""
)
