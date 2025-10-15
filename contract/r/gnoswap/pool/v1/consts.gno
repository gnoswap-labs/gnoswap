package v1

import u256 "gno.land/p/gnoswap/uint256"

var (
	minSqrtRatio = u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio = u256.MustFromDecimal(MAX_SQRT_RATIO)

	Q192 = u256.Zero().Lsh(u256.One(), 192)
)

const (
	FeeTier100   uint32 = 100
	FeeTier500   uint32 = 500
	FeeTier3000  uint32 = 3000
	FeeTier10000 uint32 = 10000
)

const (
	GNOT           string = "gnot"
	WRAPPED_WUGNOT string = "gno.land/r/gnoland/wugnot"
	GNS_PATH       string = "gno.land/r/gnoswap/gns"

	MIN_SQRT_RATIO string = "4295128739"
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342"

	MAX_UINT64  string = "18446744073709551615"
	MAX_INT64   string = "9223372036854775807"
	MAX_INT128  string = "170141183460469231731687303715884105727"
	MAX_UINT128 string = "340282366920938463463374607431768211455"

	INT64_MIN int64 = -9223372036854775808
	INT64_MAX int64 = 9223372036854775807

	Q96_RESOLUTION  uint = 96
	Q128_RESOLUTION uint = 128

	Q64  string = "18446744073709551616"                    // 2 ** 64
	Q96  string = "79228162514264337593543950336"           // 2 ** 96
	Q128 string = "340282366920938463463374607431768211456" // 2 ** 128

	MIN_TICK int32 = -887272
	MAX_TICK int32 = 887272
)
