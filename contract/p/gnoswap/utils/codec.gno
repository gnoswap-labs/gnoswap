package utils

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt/v0"
)

// EncodeUint16 converts a uint16 into a fixed-width 2-byte big-endian string.
func EncodeUint16(value uint16) string {
	var buf [2]byte
	buf[0] = byte(value >> 8)
	buf[1] = byte(value)
	return string(buf[:])
}

// DecodeUint16 converts a fixed-width 2-byte big-endian string into a uint16.
func DecodeUint16(key string) uint16 {
	if len(key) != 2 {
		panic(ufmt.Sprintf("invalid uint16 key length: %d", len(key)))
	}
	return uint16(key[0])<<8 | uint16(key[1])
}

// EncodeInt32 converts an int32 into a fixed-width 4-byte big-endian string
// whose lexicographic order matches the signed numeric order.
func EncodeInt32(value int32) string {
	ordered := uint32(value) ^ (uint32(1) << 31)
	var buf [4]byte
	buf[0] = byte(ordered >> 24)
	buf[1] = byte(ordered >> 16)
	buf[2] = byte(ordered >> 8)
	buf[3] = byte(ordered)
	return string(buf[:])
}

// DecodeInt32 converts an order-preserving 4-byte big-endian string into an int32.
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

// EncodeUint64 converts a uint64 into a fixed-width 8-byte big-endian string.
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

// DecodeUint64 converts a fixed-width 8-byte big-endian string into a uint64.
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

// EncodeUint256 converts a uint256 into a fixed-width 32-byte big-endian string.
func EncodeUint256(value *u256.Uint) string {
	return EncodeUint64(value[3]) + EncodeUint64(value[2]) +
		EncodeUint64(value[1]) + EncodeUint64(value[0])
}

// DecodeUint256 converts a fixed-width 32-byte big-endian string into a uint256.
// It returns a new value and panics if the input is not exactly 32 bytes.
func DecodeUint256(encoded string) *u256.Uint {
	if len(encoded) != 32 {
		panic(ufmt.Sprintf("invalid uint256 encoding length: %d", len(encoded)))
	}
	return u256.Zero().SetBytes([]byte(encoded))
}

// EncodeUint128 converts a uint256 into a fixed-width 16-byte big-endian string.
// It panics when value exceeds the uint128 range.
func EncodeUint128(value *u256.Uint) string {
	if value == nil {
		panic("cannot encode nil uint128")
	}
	if value[2]|value[3] != 0 {
		panic(ufmt.Sprintf("uint128 overflow: %s", value.ToString()))
	}
	return EncodeUint64(value[1]) + EncodeUint64(value[0])
}

// DecodeUint128 converts a fixed-width 16-byte big-endian string into a uint256.
// It returns a new value and panics if input is not exactly 16 bytes.
func DecodeUint128(encoded string) *u256.Uint {
	if len(encoded) != 16 {
		panic(ufmt.Sprintf("invalid uint128 encoding length: %d", len(encoded)))
	}
	return u256.Zero().SetBytes([]byte(encoded))
}
