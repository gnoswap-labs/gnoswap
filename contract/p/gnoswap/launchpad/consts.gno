package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

const (
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
