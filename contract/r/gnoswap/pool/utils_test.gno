package pool

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestEncodeTickKey(t *testing.T) {
	tests := []struct {
		name string
		tick int32
		want string
	}{
		{"zero tick", 0, "0000887272"},
		{"positive tick", 100, "0000887372"},
		{"negative tick", -100, "0000887172"},
		{"max tick", MAX_TICK, "0001774544"},
		{"min tick", -MAX_TICK, "0000000000"},
		{"large positive", 500000, "0001387272"},
		{"large negative", -500000, "0000387272"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := EncodeTickKey(tt.tick)
			uassert.Equal(t, tt.want, got)
			uassert.Equal(t, 10, len(got))
		})
	}
}

func TestDecodeTickKey(t *testing.T) {
	tests := []struct {
		name    string
		encoded string
		want    int32
	}{
		{"zero tick", "0000887272", 0},
		{"positive tick", "0000887372", 100},
		{"negative tick", "0000887172", -100},
		{"max tick", "0001774544", MAX_TICK},
		{"min tick", "0000000000", -MAX_TICK},
		{"large positive", "0001387272", 500000},
		{"large negative", "0000387272", -500000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DecodeTickKey(tt.encoded)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestEncodeDecodeTickKey_RoundTrip(t *testing.T) {
	ticks := []int32{-MAX_TICK, -500000, -100000, -60000, -1000, -100, -1, 0, 1, 100, 1000, 60000, 100000, 500000, MAX_TICK}

	for _, tick := range ticks {
		encoded := EncodeTickKey(tick)
		decoded := DecodeTickKey(encoded)
		uassert.Equal(t, tick, decoded)
	}
}

func TestEncodeTickKey_Ordering(t *testing.T) {
	key1 := EncodeTickKey(-100)
	key2 := EncodeTickKey(0)
	key3 := EncodeTickKey(100)

	uassert.True(t, key1 < key2)
	uassert.True(t, key2 < key3)
	uassert.True(t, key1 < key3)
}

func TestEncodePositionKey(t *testing.T) {
	tests := []struct {
		name      string
		tickLower int32
		tickUpper int32
		want      string
	}{
		{"narrow range", -60, 60, "00008872120000887332"},
		{"negative range", -2000, -1000, "00008852720000886272"},
		{"wide range", -887220, 887220, "00000000520001774492"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := EncodePositionKey(tt.tickLower, tt.tickUpper)
			uassert.Equal(t, tt.want, got)
			uassert.Equal(t, 20, len(got))
		})
	}
}

func TestEncodePositionKey_ComposesTickKeys(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			want := EncodeTickKey(tt.tickLower) + EncodeTickKey(tt.tickUpper)
			got := EncodePositionKey(tt.tickLower, tt.tickUpper)

			uassert.Equal(t, want, got)
		})
	}
}

func TestEncodePositionKey_Ordering(t *testing.T) {
	left := EncodePositionKey(-120, 60)
	middle := EncodePositionKey(-60, 60)
	right := EncodePositionKey(-60, 120)

	uassert.True(t, left < middle)
	uassert.True(t, middle < right)
	uassert.True(t, left < right)
}

func TestGetPoolPath(t *testing.T) {
	tests := []struct {
		name       string
		token0Path string
		token1Path string
		fee        uint32
		want       string
	}{
		{
			name:       "normal order",
			token0Path: "gno.land/r/gnoswap/test_token/atom",
			token1Path: "gno.land/r/gnoswap/test_token/btc",
			fee:        500,
			want:       "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:500",
		},
		{
			name:       "reversed order",
			token0Path: "gno.land/r/gnoswap/test_token/btc",
			token1Path: "gno.land/r/gnoswap/test_token/atom",
			fee:        500,
			want:       "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:500",
		},
		{
			name:       "fee 3000",
			token0Path: "gno.land/r/gnoswap/test_token/atom",
			token1Path: "gno.land/r/gnoswap/test_token/sol",
			fee:        3000,
			want:       "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:3000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
			uassert.Equal(t, tt.want, got)
		})
	}
}
