package pool

import (
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

func bitMathMostSignificantBit(x bigint) uint8 {
	require(x > 0, ufmt.Sprintf("[POOL] bit_math.gno__bitMathMostSignificantBit() || x(%s) > 0", x))

	r := uint8(0)

	if x >= 0x100000000000000000000000000000000 {
		x >>= 128
		r += 128
	}

	if x >= 0x10000000000000000 {
		x >>= 64
		r += 64
	}

	if x >= 0x100000000 {
		x >>= 32
		r += 32
	}

	if x >= 0x10000 {
		x >>= 16
		r += 16
	}

	if x >= 0x100 {
		x >>= 8
		r += 8
	}

	if x >= 0x10 {
		x >>= 4
		r += 4
	}

	if x >= 0x4 {
		x >>= 2
		r += 2
	}

	if x >= 0x2 {
		r += 1
	}

	return r
}

func bitMathLeastSignificantBit(x bigint) uint8 {
	require(x > 0, ufmt.Sprintf("[POOL] bit_math.gno__bitMathLeastSignificantBit() || x(%s) > 0", x))

	r := uint8(255)

	if x&consts.MAX_UINT128 > 0 {
		r -= 128
	} else {
		x >>= 128
	}

	if x&consts.MAX_UINT64 > 0 {
		r -= 64
	} else {
		x >>= 64
	}

	if x&consts.MAX_UINT32 > 0 {
		r -= 32
	} else {
		x >>= 32
	}

	if x&consts.MAX_UINT16 > 0 {
		r -= 16
	} else {
		x >>= 16
	}

	if x&consts.MAX_UINT8 > 0 {
		r -= 8
	} else {
		x >>= 8
	}

	if x&0xf > 0 {
		r -= 4
	} else {
		x >>= 4
	}

	if x&0x3 > 0 {
		r -= 2
	} else {
		x >>= 2
	}

	if x&0x1 > 0 {
		r -= 1
	}

	return r
}
