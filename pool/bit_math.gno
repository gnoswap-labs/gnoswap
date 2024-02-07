package pool

import (
	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/u256"
)

func bitMathMostSignificantBit(x *u256.Uint) uint8 {
	require(x.Gt(u256.NewUint(0)), ufmt.Sprintf("[POOL] bit_math.gno__bitMathMostSignificantBit() || x(%s) > 0", x))

	r := uint8(0)
	if x.Gte(u256.FromBigint(0x100000000000000000000000000000000)) {
		x.Rsh(x, 128)
		r += 128
	}

	if x.Gte(u256.FromBigint(0x10000000000000000)) {
		x.Rsh(x, 64)
		r += 64
	}

	if x.Gte(u256.NewUint(0x100000000)) {
		x.Rsh(x, 32)
		r += 32
	}

	if x.Gte(u256.NewUint(0x10000)) {
		x.Rsh(x, 16)
		r += 16
	}

	if x.Gte(u256.NewUint(0x100)) {
		x.Rsh(x, 8)
		r += 8
	}

	if x.Gte(u256.NewUint(0x10)) {
		x.Rsh(x, 4)
		r += 4
	}

	if x.Gte(u256.NewUint(0x4)) {
		x.Rsh(x, 2)
		r += 2
	}

	if x.Gte(u256.NewUint(0x2)) {
		r += 1
	}

	return r
}

func bitMathLeastSignificantBit(x *u256.Uint) uint8 {
	require(x.Gt(u256.NewUint(0)), ufmt.Sprintf("[POOL] bit_math.gno__bitMathLeastSignificantBit() || x(%s) > 0", x))

	r := uint8(255)

	if u256.NewUint(0).And(x, u256.FromBigint(MAX_UINT128)).Gt(u256.NewUint(0)) {
		r -= 128
	} else {
		x.Rsh(x, 128)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(MAX_UINT64)).Gt(u256.NewUint(0)) {
		r -= 64
	} else {
		x.Rsh(x, 64)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(MAX_UINT32)).Gt(u256.NewUint(0)) {
		r -= 32
	} else {
		x.Rsh(x, 32)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(MAX_UINT16)).Gt(u256.NewUint(0)) {
		r -= 16
	} else {
		x.Rsh(x, 16)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(MAX_UINT8)).Gt(u256.NewUint(0)) {
		r -= 8
	} else {
		x.Rsh(x, 8)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(0xf)).Gt(u256.NewUint(0)) {
		r -= 4
	} else {
		x.Rsh(x, 4)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(0x3)).Gt(u256.NewUint(0)) {
		r -= 2
	} else {
		x.Rsh(x, 2)
	}

	if u256.NewUint(0).And(x, u256.FromBigint(0x1)).Gt(u256.NewUint(0)) {
		r -= 1
	}

	return r
}
