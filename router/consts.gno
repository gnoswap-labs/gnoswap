package router

import "std"

const (
	MIN_PRICE bigint = 4295128740                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE bigint = 1461446703485210103287273052203988822378723970341 // MAX_SQRT_RATIO - 1

	Q96         bigint = 79228162514264337593543950336 // 2 ** 96
	MAX_UINT256 bigint = 115792089237316195423570985008687907853269984665640564039457584007913129639935

	MAX_UINT64 uint64 = 18446744073709551615

	ADDR_POOL   std.Address = std.DerivePkgAddr("gno.land/r/demo/pool")
	ADDR_ROUTER std.Address = std.DerivePkgAddr("gno.land/r/demo/router")

	// SwapType
	ExactIn  SwapType = "EXACT_IN"
	ExactOut SwapType = "EXACT_OUT"

	WGNOT_PATH = "gno.land/r/demo/wugnot"
)
