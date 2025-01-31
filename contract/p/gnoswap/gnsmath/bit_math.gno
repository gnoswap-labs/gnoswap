package gnsmath

import (
	u256 "gno.land/p/gnoswap/uint256"
)

type bitShift struct {
	bitPattern *u256.Uint
	shift      uint
}

var (
	square_2_128 = u256.MustFromDecimal(Q128)
	square_2_64  = u256.MustFromDecimal(Q64)
	square_2_32  = u256.NewUint(0x100000000)
	square_2_16  = u256.NewUint(0x10000)
	square_2_8   = u256.NewUint(0x100)
	square_2_4   = u256.NewUint(0x10)
	square_2_2   = u256.NewUint(0x4)
	square_2_1   = u256.NewUint(0x2)
)

var (
	max_uint128 = u256.MustFromDecimal(MAX_UINT128)
	max_uint64  = u256.MustFromDecimal(MAX_UINT64)
	max_uint32  = u256.MustFromDecimal(MAX_UINT32)
	max_uint16  = u256.MustFromDecimal(MAX_UINT16)
	max_uint8   = u256.MustFromDecimal(MAX_UINT8)
	num_15      = u256.MustFromDecimal(0xf)
	num_3       = u256.MustFromDecimal(0x3)
	num_1       = u256.MustFromDecimal(0x1)
)

// BitMathMostSignificantBit returns the index of the most significant bit set to 1 in the given Uint.
func BitMathMostSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic("BitMathMostSignificantBit: x should not be zero")
	}

	shifts := []bitShift{
		{square_2_128, 128},
		{square_2_64, 64},
		{square_2_32, 32},
		{square_2_16, 16},
		{square_2_8, 8},
		{square_2_4, 4},
		{square_2_2, 2},
		{square_2_1, 1},
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

// BitMathLeastSignificantBit returns the index of the least significant bit set to 1 in the given Uint.
func BitMathLeastSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic("BitMathLeastSignificantBit: x should not be zero")
	}

	shifts := []bitShift{
		{max_uint128, 128},
		{max_uint64, 64},
		{max_uint32, 32},
		{max_uint16, 16},
		{max_uint8, 8},
		{num_15, 4},
		{num_3, 2},
		{num_1, 1},
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
