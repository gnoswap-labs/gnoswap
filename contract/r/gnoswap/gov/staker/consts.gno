package staker

import (
	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	minimumAmount = 1_000_000 // 1 GNS
)

var (
	q128 = u256.MustFromDecimal(consts.Q128)
)
