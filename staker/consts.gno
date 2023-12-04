package staker

import (
	"std"
)

const (
	ZERO_ADDRESS = std.Address("")

	Q96  bigint = 79228162514264337593543950336           // 2 ** 96
	Q128 bigint = 340282366920938463463374607431768211456 // 2 ** 128

	TIMESTAMP_1DAY    uint64 = 86400
	TIMESTAMP_90DAYS  uint64 = 7776000
	TIMESTAMP_180DAYS uint64 = 15552000
	TIMESTAMP_360DAYS uint64 = 31104000
)

// WRAP & UNWRAP
const (
	GNOT           = "gnot"
	WRAPPED_WUGNOT = "gno.land/r/wugnot"
)
