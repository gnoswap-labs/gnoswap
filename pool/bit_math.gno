package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"

	"gno.land/p/demo/u256"
)

type bitShift struct {
	bitPattern *u256.Uint // mask or limit
	shift      uint
}

func bitMathMostSignificantBit(x *u256.Uint) uint8 {
	require(
		!x.IsZero(),
		ufmt.Sprintf("[POOL] bit_math.gno__bitMathMostSignificantBit() || expected x(%d) != 0", x),
	)

	shifts := []bitShift{
		{u256.FromBigint(0x100000000000000000000000000000000), 128},
		{u256.FromBigint(0x10000000000000000), 64},
		{u256.FromBigint(0x100000000), 32},
		{u256.FromBigint(0x10000), 16},
		{u256.FromBigint(0x100), 8},
		{u256.FromBigint(0x10), 4},
		{u256.FromBigint(0x4), 2},
		{u256.FromBigint(0x2), 1},
	}

	r := uint8(0)
	for _, s := range shifts {
		if x.Gte(s.bitPattern) {
			x.Rsh(x, s.shift)
			r += uint8(s.shift)
		}
	}

	return r
}

func bitMathLeastSignificantBit(x *u256.Uint) uint8 {
	require(
		!x.IsZero(),
		ufmt.Sprintf("[POOL] bit_math.gno__bitMathLeastSignificantBit() || expected x(%d) != 0", x),
	)

	shifts := []bitShift{
		{u256.FromBigint(consts.MAX_UINT128), 128},
		{u256.FromBigint(consts.MAX_UINT64), 64},
		{u256.FromBigint(consts.MAX_UINT32), 32},
		{u256.FromBigint(consts.MAX_UINT16), 16},
		{u256.FromBigint(consts.MAX_UINT8), 8},
		{u256.FromBigint(0xf), 4},
		{u256.FromBigint(0x3), 2},
		{u256.FromBigint(0x1), 1},
	}

	r := uint8(255)
	for _, s := range shifts {
		if !new(u256.Uint).And(x, s.bitPattern).IsZero() {
			r -= uint8(s.shift)
		} else {
			x.Rsh(x, s.shift)
		}
	}

	return r
}
