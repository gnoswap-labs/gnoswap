package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

type bitShift struct {
	bitPattern bigint	// mask or limit
	shift      uint
}

func bitMathMostSignificantBit(x bigint) uint8 {
    requirePositive(
		x,
		ufmt.Sprintf("[POOL] bit_math.gno__bitMathMostSignificantBit() || expected x(%d) > 0", x),
	)

    shifts := []bitShift{
        {0x100000000000000000000000000000000, 128},
        {0x10000000000000000, 64},
        {0x100000000, 32},
        {0x10000, 16},
        {0x100, 8},
        {0x10, 4},
        {0x4, 2},
        {0x2, 1},
    }

    r := uint8(0)
    for _, s := range shifts {
		if x >= s.bitPattern {
			x >>= s.shift
			r += uint8(s.shift)
		}
	}

    return r
}

func bitMathLeastSignificantBit(x bigint) uint8 {
    requirePositive(
		x,
		ufmt.Sprintf("[POOL] bit_math.gno__bitMathLeastSignificantBit() || expected x(%d) > 0", x),
	)

    shifts := []bitShift{
        {consts.MAX_UINT128, 128},
        {consts.MAX_UINT64, 64},
        {consts.MAX_UINT32, 32},
        {consts.MAX_UINT16, 16},
        {consts.MAX_UINT8, 8},
        {0xf, 4},
        {0x3, 2},
        {0x1, 1},
    }

    r := uint8(255)
    for _, s := range shifts {
		if x&s.bitPattern > 0 {
			r -= uint8(s.shift)
		} else {
			x >>= s.shift
		}
	}

    return r
}
