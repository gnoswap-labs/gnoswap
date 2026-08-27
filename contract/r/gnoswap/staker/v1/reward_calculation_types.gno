package staker

import ufmt "gno.land/p/nt/ufmt/v0"

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
	var buf [8]byte
	buf[0] = byte(num >> 56)
	buf[1] = byte(num >> 48)
	buf[2] = byte(num >> 40)
	buf[3] = byte(num >> 32)
	buf[4] = byte(num >> 24)
	buf[5] = byte(num >> 16)
	buf[6] = byte(num >> 8)
	buf[7] = byte(num)
	return string(buf[:])
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
	if len(s) != 8 {
		panic(ufmt.Sprintf("invalid uint64 key length: %d", len(s)))
	}
	return uint64(s[0])<<56 |
		uint64(s[1])<<48 |
		uint64(s[2])<<40 |
		uint64(s[3])<<32 |
		uint64(s[4])<<24 |
		uint64(s[5])<<16 |
		uint64(s[6])<<8 |
		uint64(s[7])
}

func DecodeInt64(s string) int64 {
	num := DecodeUint(s)
	if num > 9223372036854775807 {
		panic(ufmt.Sprintf("uint64 key overflows int64: %d", num))
	}
	return int64(num)
}
