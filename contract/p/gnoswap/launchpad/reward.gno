package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	q128 = u256.Zero()
)

func init() {
	q128 = u256.MustFromDecimal(consts.Q128)
}

// CalculateTierRewardRate calculates the reward per block with Q128 precision
func CalculateTierRewardRate(tierAmount uint64, duration uint64) *u256.Uint {
	tierAmountX128 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q128)
	return new(u256.Uint).Div(tierAmountX128, u256.NewUint(duration))
}
