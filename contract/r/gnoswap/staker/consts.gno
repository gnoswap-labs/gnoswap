package staker

import u256 "gno.land/p/gnoswap/uint256"

// WRAP & UNWRAP
const (
	GNOT string = "gnot"

	// ref: https://github.com/gnolang/gno/blob/81a88a2976ba9f2f9127ebbe7fb7d1e1f7fa4bd4/examples/gno.land/r/demo/wugnot/wugnot.gno#L19
	UGNOT_MIN_DEPOSIT_TO_WRAP uint64 = 1000

	GNS_PATH    string = "gno.land/r/gnoswap/v1/gns"
	WUGNOT_PATH string = "gno.land/r/demo/wugnot"
)

var (
	// Q128 is 2^128 for standard precision
	q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
	// Q192 is 2^192
	q192 = u256.MustFromDecimal("6277101735386680763835789423207666416102355444464034512896")
)
