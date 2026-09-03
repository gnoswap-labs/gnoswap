package utils

import (
	"math"
	"testing"

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
