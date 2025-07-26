package staker

import (
	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	minimumAmount = 1_000_000 // 1 GNS
)

// WRAP & UNWRAP
const (
	GNOT string = "gnot"

	// ref: https://github.com/gnolang/gno/blob/81a88a2976ba9f2f9127ebbe7fb7d1e1f7fa4bd4/examples/gno.land/r/demo/wugnot/wugnot.gno#L19
	UGNOT_MIN_DEPOSIT_TO_WRAP uint64 = 1000
)

var q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
