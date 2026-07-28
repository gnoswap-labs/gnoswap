package gnsmath

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// bitShift represents a bit pattern and corresponding shift amount for bit manipulation.
type bitShift struct {
	bitPattern *u256.Uint
	shift      uint
}

// newMsbShifts returns the descending power-of-two thresholds used by
// BitMathMostSignificantBit. It is a constructor (not a package-level var) so
// each call yields freshly allocated bit patterns that callers never share.
// Values are built from little-endian [4]uint64 literals to avoid runtime
// shift computations.
func newMsbShifts() []bitShift {
	return []bitShift{
		{&u256.Uint{0, 0, 1, 0}, 128},         // 2^128
		{&u256.Uint{0, 1, 0, 0}, 64},          // 2^64
		{&u256.Uint{4294967296, 0, 0, 0}, 32}, // 2^32
		{&u256.Uint{65536, 0, 0, 0}, 16},      // 2^16
		{&u256.Uint{256, 0, 0, 0}, 8},         // 2^8
		{&u256.Uint{16, 0, 0, 0}, 4},          // 2^4
		{&u256.Uint{4, 0, 0, 0}, 2},           // 2^2
		{&u256.Uint{2, 0, 0, 0}, 1},           // 2^1
	}
}

// newLsbShifts returns the descending (2^n - 1) masks used by
// BitMathLeastSignificantBit. See newMsbShifts for rationale.
func newLsbShifts() []bitShift {
	return []bitShift{
		{&u256.Uint{18446744073709551615, 18446744073709551615, 0, 0}, 128}, // 2^128 - 1
		{&u256.Uint{18446744073709551615, 0, 0, 0}, 64},                     // 2^64 - 1
		{&u256.Uint{4294967295, 0, 0, 0}, 32},                               // 2^32 - 1
		{&u256.Uint{65535, 0, 0, 0}, 16},                                    // 2^16 - 1
		{&u256.Uint{255, 0, 0, 0}, 8},                                       // 2^8 - 1
		{&u256.Uint{0xf, 0, 0, 0}, 4},                                       // 2^4 - 1 = 15
		{&u256.Uint{0x3, 0, 0, 0}, 2},                                       // 2^2 - 1 = 3
		{&u256.Uint{0x1, 0, 0, 0}, 1},                                       // 2^1 - 1 = 1
	}
}

// BitMathMostSignificantBit returns the 0-based position of the most significant bit in x.
// This function is essential for AMM calculations involving price ranges and tick boundaries.
//
// Parameters:
//   - x: the value for which to compute the most significant bit
//
// Returns the index of the most significant bit (0-255).
//
// Panics if x is zero.
func BitMathMostSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic(errMSBZeroInput)
	}

	temp := x.Clone()
	r := uint8(0)

	for _, s := range newMsbShifts() {
		if temp.Gte(s.bitPattern) {
			temp = temp.Rsh(temp, s.shift)
			r += uint8(s.shift)
		}
	}

	return r
}

// BitMathLeastSignificantBit returns the 0-based position of the least significant bit in x.
// This function is used in AMM calculations for efficient bit manipulation and range queries.
//
// Parameters:
//   - x: the value for which to compute the least significant bit
//
// Returns the index of the least significant bit (0-255).
//
// Panics if x is zero.
func BitMathLeastSignificantBit(x *u256.Uint) uint8 {
	if x.IsZero() {
		panic(errLSBZeroInput)
	}

	temp := x.Clone()
	hasSetBits := u256.Zero()
	r := uint8(255)

	for _, s := range newLsbShifts() {
		hasSetBits = hasSetBits.And(temp, s.bitPattern)
		if !hasSetBits.IsZero() {
			r -= uint8(s.shift)
		} else {
			temp = temp.Rsh(temp, s.shift)
		}
	}

	return r
}
