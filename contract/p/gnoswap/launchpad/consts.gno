package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	TIMESTAMP_180DAYS = uint64(180 * 24 * 60 * 60) // 15552000
	TIMESTAMP_14DAYS  = uint64(14 * 24 * 60 * 60)  // 1209600
	TIMESTAMP_90DAYS  = uint64(90 * 24 * 60 * 60)  // 7776000
	TIMESTAMP_7DAYS   = uint64(7 * 24 * 60 * 60)   // 604800
	TIMESTAMP_30DAYS  = uint64(30 * 24 * 60 * 60)  // 2592000
	TIMESTAMP_3DAYS   = uint64(3 * 24 * 60 * 60)   // 259200
	TIMESTAMP_DAY     = uint64(24 * 60 * 60)       // 86400

	PAD_SEP = "*PAD*"

	Q128 string = "340282366920938463463374607431768211456" // 2 ** 128
)

var q128 = u256.Zero()

func init() {
	q128 = u256.MustFromDecimal(Q128)
}

const (
	TIER30  = uint64(30)
	TIER90  = uint64(90)
	TIER180 = uint64(180)
)
