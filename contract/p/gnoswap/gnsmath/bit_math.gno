package gnsmath

import (
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	msbShifts = []bitShift{
		{u256.Zero().Lsh(u256.One(), 128), 128}, // 2^128
		{u256.Zero().Lsh(u256.One(), 64), 64},   // 2^64
		{u256.Zero().Lsh(u256.One(), 32), 32},   // 2^32
		{u256.Zero().Lsh(u256.One(), 16), 16},   // 2^16
		{u256.Zero().Lsh(u256.One(), 8), 8},     // 2^8
		{u256.Zero().Lsh(u256.One(), 4), 4},     // 2^4
		{u256.Zero().Lsh(u256.One(), 2), 2},     // 2^2
		{u256.Zero().Lsh(u256.One(), 1), 1},     // 2^1
	}

	lsbShifts = []bitShift{
		{u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 128), u256.One()), 128}, // 2^128 - 1
		{u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 64), u256.One()), 64},   // 2^64 - 1
		{u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 32), u256.One()), 32},   // 2^32 - 1
		{u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 16), u256.One()), 16},   // 2^16 - 1
		{u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 8), u256.One()), 8},     // 2^8 - 1
		{u256.NewUint(0xf), 4}, // 2^4 - 1 = 15
		{u256.NewUint(0x3), 2}, // 2^2 - 1 = 3
		{u256.NewUint(0x1), 1}, // 2^1 - 1 = 1
	}
)

// bitShift represents a bit pattern and corresponding shift amount for bit manipulation.
type bitShift struct {
	bitPattern *u256.Uint
	shift      uint
}

// BitMathMostSignificantBit returns the 0-based position of the most significant bit in x.
// This function is essential for AMM calculations involving price ranges and tick boundaries.
// Panics if x is zero.
func BitMathMostSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic(errMSBZeroInput)
	}

	temp := x.Clone()
	r := uint8(0)

	for _, s := range msbShifts {
		if temp.Gte(s.bitPattern) {
			temp = temp.Rsh(temp, s.shift)
			r += uint8(s.shift)
		}
	}

	return r
}

// BitMathLeastSignificantBit returns the 0-based position of the least significant bit in x.
// This function is used in AMM calculations for efficient bit manipulation and range queries.
// Panics if x is zero.
func BitMathLeastSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic(errLSBZeroInput)
	}

	temp := x.Clone()
	hasSetBits := u256.Zero()
	r := uint8(255)

	for _, s := range lsbShifts {
		hasSetBits = hasSetBits.And(temp, s.bitPattern)
		if !hasSetBits.IsZero() {
			r -= uint8(s.shift)
		} else {
			temp = temp.Rsh(temp, s.shift)
		}
	}

	return r
}
