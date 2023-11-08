package router

import "std"

const (
	BASE_TOKEN = "gno.land/r/wugnot" // find_path.gno

	MIN_PRICE bigint = 4295128740                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE bigint = 1461446703485210103287273052203988822378723970341 // MAX_SQRT_RATIO - 1

	Q96 bigint = 79228162514264337593543950336 // 2 ** 96

	ADDR_POOL   std.Address = std.DerivePkgAddr("gno.land/r/pool")
	ADDR_ROUTER std.Address = std.DerivePkgAddr("gno.land/r/router")
)
