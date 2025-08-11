package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	GNOT          string = "gnot"
	minimumAmount        = 1_000_000 // 1 GNS
)

var q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
