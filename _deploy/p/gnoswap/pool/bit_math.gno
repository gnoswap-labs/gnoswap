package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

type bitShift struct {
	bitPattern *u256.Uint
	shift      uint
}

func BitMathMostSignificantBit(x *u256.Uint) uint8 {
	shifts := []bitShift{
		{u256.MustFromDecimal(Q128), 128}, // 2^128
		{u256.MustFromDecimal(Q64), 64},   // 2^64
		{u256.NewUint(0x100000000), 32},
		{u256.NewUint(0x10000), 16},
		{u256.NewUint(0x100), 8},
		{u256.NewUint(0x10), 4},
		{u256.NewUint(0x4), 2},
		{u256.NewUint(0x2), 1},
	}

	r := uint8(0)
	for _, s := range shifts {
		if x.Gte(s.bitPattern) {
			x = new(u256.Uint).Rsh(x, s.shift)
			r += uint8(s.shift)
		}
	}

	return r
}

func BitMathLeastSignificantBit(x *u256.Uint) uint8 {
	shifts := []bitShift{
		{u256.MustFromDecimal(MAX_UINT128), 128},
		{u256.MustFromDecimal(MAX_UINT64), 64},
		{u256.MustFromDecimal(MAX_UINT32), 32},
		{u256.MustFromDecimal(MAX_UINT16), 16},
		{u256.MustFromDecimal(MAX_UINT8), 8},
		{u256.NewUint(0xf), 4},
		{u256.NewUint(0x3), 2},
		{u256.NewUint(0x1), 1},
	}

	r := uint8(255)
	for _, s := range shifts {
		if new(u256.Uint).And(x, s.bitPattern).Gt(u256.Zero()) {
			r -= uint8(s.shift)
		} else {
			x = new(u256.Uint).Rsh(x, s.shift)
		}
	}

	return r
}
