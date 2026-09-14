package utils

import (
	"math"
	"strings"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestUint16Codec(cur realm, t *testing.T) {
	tests := []struct {
		value uint16
		want  [2]byte
	}{
		{0, [2]byte{0, 0}},
		{1, [2]byte{0, 1}},
		{255, [2]byte{0, 255}},
		{256, [2]byte{1, 0}},
		{65535, [2]byte{255, 255}},
	}

	previous := ""
	for _, tt := range tests {
		encoded := EncodeUint16(tt.value)
		uassert.Equal(t, 2, len(encoded))
		uassert.Equal(t, tt.want[0], encoded[0])
		uassert.Equal(t, tt.want[1], encoded[1])
		uassert.Equal(t, tt.value, DecodeUint16(encoded))
		if previous != "" && !(previous < encoded) {
			t.Errorf("encoded keys are not lexicographically ordered: %d", tt.value)
		}
		previous = encoded
	}

	uassert.PanicsWithMessage(t, cur, "invalid uint16 key length: 1", func() {
		DecodeUint16("x")
	})
}

func TestEncodeUint64(t *testing.T) {
	tests := []struct {
		name  string
		value uint64
		want  [8]byte
	}{
		{"zero", 0, [8]byte{0, 0, 0, 0, 0, 0, 0, 0}},
		{"one", 1, [8]byte{0, 0, 0, 0, 0, 0, 0, 1}},
		{"uint8 max", 255, [8]byte{0, 0, 0, 0, 0, 0, 0, 255}},
		{"uint8 boundary", 256, [8]byte{0, 0, 0, 0, 0, 0, 1, 0}},
		{"uint16 max", 65535, [8]byte{0, 0, 0, 0, 0, 0, 255, 255}},
		{"uint32 max", 4294967295, [8]byte{0, 0, 0, 0, 255, 255, 255, 255}},
		{"int64 max", uint64(math.MaxInt64), [8]byte{127, 255, 255, 255, 255, 255, 255, 255}},
		{"uint64 max", math.MaxUint64, [8]byte{255, 255, 255, 255, 255, 255, 255, 255}},
	}

	for _, tt := range tests {
		got := EncodeUint64(tt.value)
		if len(got) != 8 {
			t.Errorf("%s: encoded length = %d; want 8", tt.name, len(got))
		}
		for i := 0; i < len(tt.want); i++ {
			uassert.Equal(t, tt.want[i], got[i])
		}
	}
}

func TestEncodeUint64PreservesOrder(t *testing.T) {
	values := []uint64{0, 1, 255, 256, 65535, 4294967295, uint64(math.MaxInt64), math.MaxUint64}
	previous := ""

	for _, value := range values {
		encoded := EncodeUint64(value)
		if previous != "" && !(previous < encoded) {
			t.Errorf("encoded keys are not lexicographically ordered: %d", value)
		}
		previous = encoded
	}
}

func TestDecodeUint64(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		key          string
		want         uint64
		panicMessage string
	}{
		{"zero", string([]byte{0, 0, 0, 0, 0, 0, 0, 0}), 0, ""},
		{"uint8 max", string([]byte{0, 0, 0, 0, 0, 0, 0, 255}), 255, ""},
		{"uint8 boundary", string([]byte{0, 0, 0, 0, 0, 0, 1, 0}), 256, ""},
		{"uint32 max", string([]byte{0, 0, 0, 0, 255, 255, 255, 255}), 4294967295, ""},
		{"int64 max", string([]byte{127, 255, 255, 255, 255, 255, 255, 255}), uint64(math.MaxInt64), ""},
		{"uint64 max", string([]byte{255, 255, 255, 255, 255, 255, 255, 255}), math.MaxUint64, ""},
		{"empty", "", 0, "invalid uint64 key length: 0"},
		{"short", "1234567", 0, "invalid uint64 key length: 7"},
		{"long", "123456789", 0, "invalid uint64 key length: 9"},
	}

	for _, tt := range tests {
		if tt.panicMessage != "" {
			uassert.PanicsWithMessage(t, cur, tt.panicMessage, func() {
				DecodeUint64(tt.key)
			})
			continue
		}
		uassert.Equal(t, tt.want, DecodeUint64(tt.key))
	}
}

func TestUint256Codec(t *testing.T) {
	tests := []struct {
		name    string
		value   u256.Uint
		encoded string
	}{
		{"zero", u256.Uint{}, strings.Repeat("\x00", 32)},
		{"one", u256.Uint{1}, strings.Repeat("\x00", 31) + "\x01"},
		{"uint64 max", u256.Uint{math.MaxUint64}, strings.Repeat("\x00", 24) + strings.Repeat("\xff", 8)},
		{"uint64 boundary", u256.Uint{0, 1}, strings.Repeat("\x00", 23) + "\x01" + strings.Repeat("\x00", 8)},
		{"uint128 max", u256.Uint{math.MaxUint64, math.MaxUint64}, strings.Repeat("\x00", 16) + strings.Repeat("\xff", 16)},
		{"uint128 boundary", u256.Uint{0, 0, 1}, strings.Repeat("\x00", 15) + "\x01" + strings.Repeat("\x00", 16)},
		{"uint192 max", u256.Uint{math.MaxUint64, math.MaxUint64, math.MaxUint64}, strings.Repeat("\x00", 8) + strings.Repeat("\xff", 24)},
		{"uint192 boundary", u256.Uint{0, 0, 0, 1}, strings.Repeat("\x00", 7) + "\x01" + strings.Repeat("\x00", 24)},
		{"high bit", u256.Uint{0, 0, 0, uint64(1) << 63}, "\x80" + strings.Repeat("\x00", 31)},
		{"uint256 max", u256.Uint{math.MaxUint64, math.MaxUint64, math.MaxUint64, math.MaxUint64}, strings.Repeat("\xff", 32)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Independent byte vectors catch matching encoder/decoder mistakes.
			uassert.Equal(t, tt.encoded, EncodeUint256(&tt.value))
			uassert.Equal(t, tt.value.ToString(), DecodeUint256(tt.encoded).ToString())
		})
	}
}

func TestEncodeUint256PreservesOrder(t *testing.T) {
	values := []u256.Uint{
		{},
		{1},
		{math.MaxUint64},
		{0, 1},
		{math.MaxUint64, math.MaxUint64},
		{0, 0, 1},
		{math.MaxUint64, math.MaxUint64, math.MaxUint64},
		{0, 0, 0, 1},
		{0, 0, 0, uint64(1) << 63},
		{math.MaxUint64, math.MaxUint64, math.MaxUint64, math.MaxUint64},
	}
	previous := ""
	for _, value := range values {
		encoded := EncodeUint256(&value)
		if previous != "" && !(previous < encoded) {
			t.Errorf("encoded keys are not lexicographically ordered: %s", value.ToString())
		}
		previous = encoded
	}
}

func TestUint256CodecByteOrder(t *testing.T) {
	value := &u256.Uint{
		0x18191a1b1c1d1e1f,
		0x1011121314151617,
		0x08090a0b0c0d0e0f,
		0x0001020304050607,
	}
	var bytes [32]byte
	for i := range bytes {
		bytes[i] = byte(i)
	}
	encoded := string(bytes[:])
	uassert.Equal(t, encoded, EncodeUint256(value))
	uassert.Equal(t, value.ToString(), DecodeUint256(encoded).ToString())

	// Decoding must not share mutable values between callers.
	decoded := DecodeUint256(encoded)
	decoded.Set(u256.Zero())
	uassert.Equal(t, value.ToString(), DecodeUint256(encoded).ToString())
}

func TestDecodeUint256RejectsInvalidLength(cur realm, t *testing.T) {
	for _, length := range []int{0, 31, 33} {
		uassert.PanicsContains(t, cur, "", func() {
			DecodeUint256(string(make([]byte, length)))
		})
	}
}
