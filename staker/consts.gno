package staker

import (
	"std"
)

const (
	ZERO_ADDRESS = std.Address("")

	Q96  bigint = 79228162514264337593543950336           // 2 ** 96
	Q128 bigint = 340282366920938463463374607431768211456 // 2 ** 128

	TIMESTAMP_1DAY   int64 = 86400
	TIMESTAMP_30DAYS int64 = 2592000
)
