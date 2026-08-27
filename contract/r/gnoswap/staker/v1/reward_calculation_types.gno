package staker

import (
	"math"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/gnoswap/utils"
)

// EncodeUint converts a uint64 number into a fixed-width 8-byte big-endian string.
//
// Parameters:
// - num (uint64): The number to encode.
//
// Returns:
// - string: An 8-byte binary string representation of the number.
//
// Big-endian encoding preserves numeric ordering under the B+ tree's
// lexicographic key ordering.
func EncodeUint(num uint64) string {
	return utils.EncodeUint64(num)
}

func EncodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return EncodeUint(uint64(num))
}

// DecodeUint converts an 8-byte big-endian string back into a uint64 number.
//
// Parameters:
// - s (string): The 8-byte binary string to decode.
//
// Returns:
// - uint64: The decoded number.
//
// Panics:
// - If s is not exactly 8 bytes long.
func DecodeUint(s string) uint64 {
	return utils.DecodeUint64(s)
}

func DecodeInt64(s string) int64 {
	num := DecodeUint(s)
	if num > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf("uint64 key overflows int64: %d", num))
	}
	return int64(num)
}
