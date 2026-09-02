package utils

import ufmt "gno.land/p/nt/ufmt/v0"

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
