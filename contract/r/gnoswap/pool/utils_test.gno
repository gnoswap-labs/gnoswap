package pool

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestEncodeTickKey(cur realm, t *testing.T) {
	tests := []struct {
		name string
		tick int32
		want string
	}{
		{"zero tick", 0, "\x80\x00\x00\x00"},
		{"positive tick", 100, "\x80\x00\x00\x64"},
		{"negative tick", -100, "\x7f\xff\xff\x9c"},
		{"max tick", MAX_TICK, "\x80\x0d\x89\xe8"},
		{"min tick", -MAX_TICK, "\x7f\xf2\x76\x18"},
		{"large positive", 500000, "\x80\x07\xa1\x20"},
		{"large negative", -500000, "\x7f\xf8\x5e\xe0"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			got := EncodeTickKey(tt.tick)
			uassert.Equal(t, tt.want, got)
			uassert.Equal(t, 4, len(got))
		})
	}
}

func TestDecodeTickKey(cur realm, t *testing.T) {
	tests := []struct {
		name    string
		encoded string
		want    int32
	}{
		{"zero tick", "\x80\x00\x00\x00", 0},
		{"positive tick", "\x80\x00\x00\x64", 100},
		{"negative tick", "\x7f\xff\xff\x9c", -100},
		{"max tick", "\x80\x0d\x89\xe8", MAX_TICK},
		{"min tick", "\x7f\xf2\x76\x18", -MAX_TICK},
		{"large positive", "\x80\x07\xa1\x20", 500000},
		{"large negative", "\x7f\xf8\x5e\xe0", -500000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			got := DecodeTickKey(tt.encoded)
			uassert.Equal(t, tt.want, got)
		})
	}

	uassert.PanicsWithMessage(t, cur, "invalid int32 key length: 3", func() {
		DecodeTickKey("123")
	})
}

func TestEncodeDecodeTickKey_RoundTrip(cur realm, t *testing.T) {
	ticks := []int32{-MAX_TICK, -500000, -100000, -60000, -1000, -100, -1, 0, 1, 100, 1000, 60000, 100000, 500000, MAX_TICK}

	for _, tick := range ticks {
		encoded := EncodeTickKey(tick)
		decoded := DecodeTickKey(encoded)
		uassert.Equal(t, tick, decoded)
	}
}

func TestEncodeTickKey_Ordering(cur realm, t *testing.T) {
	key1 := EncodeTickKey(-100)
	key2 := EncodeTickKey(0)
	key3 := EncodeTickKey(100)

	uassert.True(t, key1 < key2)
	uassert.True(t, key2 < key3)
	uassert.True(t, key1 < key3)
}

func TestEncodePositionKey(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		tickLower int32
		tickUpper int32
		want      string
	}{
		{"narrow range", -60, 60, "\x7f\xff\xff\xc4\x80\x00\x00\x3c"},
		{"negative range", -2000, -1000, "\x7f\xff\xf8\x30\x7f\xff\xfc\x18"},
		{"wide range", -887220, 887220, "\x7f\xf2\x76\x4c\x80\x0d\x89\xb4"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			got := EncodePositionKey(tt.tickLower, tt.tickUpper)
			uassert.Equal(t, tt.want, got)
			uassert.Equal(t, 8, len(got))
		})
	}
}

func TestEncodePositionKey_ComposesTickKeys(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		tickLower int32
		tickUpper int32
	}{
		{"zero range", 0, 0},
		{"mixed range", -120, 240},
		{"extreme range", -MAX_TICK, MAX_TICK},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			want := EncodeTickKey(tt.tickLower) + EncodeTickKey(tt.tickUpper)
			got := EncodePositionKey(tt.tickLower, tt.tickUpper)

			uassert.Equal(t, want, got)
		})
	}
}

func TestEncodePositionKey_Ordering(cur realm, t *testing.T) {
	left := EncodePositionKey(-120, 60)
	middle := EncodePositionKey(-60, 60)
	right := EncodePositionKey(-60, 120)

	uassert.True(t, left < middle)
	uassert.True(t, middle < right)
	uassert.True(t, left < right)
}

func TestGetPoolPath(cur realm, t *testing.T) {
	tests := []struct {
		name       string
		token0Path string
		token1Path string
		fee        uint32
		want       string
	}{
		{
			name:       "normal order",
			token0Path: "gno.land/r/onbloc/bar",
			token1Path: "gno.land/r/onbloc/foo",
			fee:        500,
			want:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		},
		{
			name:       "reversed order",
			token0Path: "gno.land/r/onbloc/foo",
			token1Path: "gno.land/r/onbloc/bar",
			fee:        500,
			want:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		},
		{
			name:       "fee 3000",
			token0Path: "gno.land/r/onbloc/bar",
			token1Path: "gno.land/r/onbloc/qux",
			fee:        3000,
			want:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			got := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
			uassert.Equal(t, tt.want, got)
		})
	}
}
