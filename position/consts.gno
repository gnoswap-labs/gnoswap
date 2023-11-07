package position

import (
	"std"
)

const (
	ZERO_ADDRESS = std.Address("")

	// some numbers
	// calculated by https://mathiasbynens.be/demo/integer-range
	MAX_UINT256 bigint = 115792089237316195423570985008687907853269984665640564039457584007913129639935

	// ETC
	Q96  bigint = 79228162514264337593543950336           // 2 ** 96
	Q128 bigint = 340282366920938463463374607431768211456 // 2 ** 128

	MAX_UINT160 bigint = 1461501637330902918203684832716283019655932542975

	// Tick Related
	MIN_TICK int32 = -887272
	MAX_TICK int32 = 887272

	MIN_SQRT_RATIO bigint = 4295128739                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO bigint = 1461446703485210103287273052203988822378723970342 // same as TickMathGetSqrtRatioAtTick(MAX_TICK)

	MIN_PRICE bigint = 4295128740                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE bigint = 1461446703485210103287273052203988822378723970341 // MAX_SQRT_RATIO - 1
)
