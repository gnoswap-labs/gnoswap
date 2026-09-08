package gnsmath

import (
	"math/bits"

	u256 "gno.land/p/gnoswap/uint256"
)

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

	return uint8(x.BitLen() - 1)
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

	if x[0] != 0 {
		return uint8(bits.TrailingZeros64(x[0]))
	}
	if x[1] != 0 {
		return uint8(64 + bits.TrailingZeros64(x[1]))
	}
	if x[2] != 0 {
		return uint8(128 + bits.TrailingZeros64(x[2]))
	}
	return uint8(192 + bits.TrailingZeros64(x[3]))
}
