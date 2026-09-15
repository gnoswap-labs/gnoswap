package utils

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt/v0"
)

// EncodeUint16 converts a uint16 to a fixed-width two-byte big-endian string.
//
// Parameters:
//   - value: Unsigned 16-bit integer to encode.
//
// Returns:
//   - encoded: Exactly two bytes in big-endian order; lexicographic order matches numeric order.
func EncodeUint16(value uint16) string {
	var buf [2]byte
	buf[0] = byte(value >> 8)
	buf[1] = byte(value)
	return string(buf[:])
}

// DecodeUint16 decodes a fixed-width two-byte big-endian string.
//
// Parameters:
//   - key: Exactly two encoded bytes, with the most-significant byte first.
//
// Returns:
//   - value: The uint16 represented by key.
//
// Panics if key is not exactly two bytes long.
func DecodeUint16(key string) uint16 {
	if len(key) != 2 {
		panic(ufmt.Sprintf("invalid uint16 key length: %d", len(key)))
	}
	return uint16(key[0])<<8 | uint16(key[1])
}

// EncodeInt32 converts an int32 to a fixed-width four-byte big-endian string.
// Flipping the sign bit makes lexicographic order match signed numeric order.
//
// Parameters:
//   - value: Signed 32-bit integer to encode.
//
// Returns:
//   - encoded: Exactly four order-preserving big-endian bytes.
func EncodeInt32(value int32) string {
	ordered := uint32(value) ^ (uint32(1) << 31)
	var buf [4]byte
	buf[0] = byte(ordered >> 24)
	buf[1] = byte(ordered >> 16)
	buf[2] = byte(ordered >> 8)
	buf[3] = byte(ordered)
	return string(buf[:])
}

// DecodeInt32 decodes a four-byte order-preserving big-endian string.
//
// Parameters:
//   - key: Exactly four bytes produced by EncodeInt32.
//
// Returns:
//   - value: The signed int32 recovered after reversing the sign-bit transform.
//
// Panics if key is not exactly four bytes long.
func DecodeInt32(key string) int32 {
	if len(key) != 4 {
		panic(ufmt.Sprintf("invalid int32 key length: %d", len(key)))
	}
	ordered := uint32(key[0])<<24 |
		uint32(key[1])<<16 |
		uint32(key[2])<<8 |
		uint32(key[3])
	return int32(ordered ^ (uint32(1) << 31))
}

// EncodeUint64 converts a uint64 to a fixed-width eight-byte big-endian string.
//
// Parameters:
//   - value: Unsigned 64-bit integer to encode.
//
// Returns:
//   - encoded: Exactly eight bytes in big-endian order.
func EncodeUint64(value uint64) string {
	var buf [8]byte
	buf[0] = byte(value >> 56)
	buf[1] = byte(value >> 48)
	buf[2] = byte(value >> 40)
	buf[3] = byte(value >> 32)
	buf[4] = byte(value >> 24)
	buf[5] = byte(value >> 16)
	buf[6] = byte(value >> 8)
	buf[7] = byte(value)
	return string(buf[:])
}

// DecodeUint64 decodes a fixed-width eight-byte big-endian string.
//
// Parameters:
//   - key: Exactly eight encoded bytes, with the most-significant byte first.
//
// Returns:
//   - value: The uint64 represented by key.
//
// Panics if key is not exactly eight bytes long.
func DecodeUint64(key string) uint64 {
	if len(key) != 8 {
		panic(ufmt.Sprintf("invalid uint64 key length: %d", len(key)))
	}
	return uint64(key[0])<<56 |
		uint64(key[1])<<48 |
		uint64(key[2])<<40 |
		uint64(key[3])<<32 |
		uint64(key[4])<<24 |
		uint64(key[5])<<16 |
		uint64(key[6])<<8 |
		uint64(key[7])
}

// EncodeUint256 converts a 256-bit unsigned integer to a fixed-width 32-byte
// big-endian string, emitting the most-significant limb first.
//
// Parameters:
//   - value: Non-nil *u256.Uint value to encode.
//
// Returns:
//   - encoded: Exactly 32 big-endian bytes representing value.
func EncodeUint256(value *u256.Uint) string {
	return EncodeUint64(value[3]) + EncodeUint64(value[2]) +
		EncodeUint64(value[1]) + EncodeUint64(value[0])
}

// DecodeUint256 decodes a fixed-width 32-byte big-endian uint256 encoding.
//
// Parameters:
//   - encoded: Exactly 32 bytes containing the most-significant byte first.
//
// Returns:
//   - value: A new *u256.Uint populated from encoded.
//
// Panics if encoded is not exactly 32 bytes long.
func DecodeUint256(encoded string) *u256.Uint {
	if len(encoded) != 32 {
		panic(ufmt.Sprintf("invalid uint256 encoding length: %d", len(encoded)))
	}
	return u256.Zero().SetBytes([]byte(encoded))
}
