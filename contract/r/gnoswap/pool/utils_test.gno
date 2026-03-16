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
		{"zero tick", 0, "000v2f8"},
		{"positive tick", 100, "000v2jc"},
		{"negative tick", -100, "000v2c4"},
		{"max tick", MAX_TICK, "001p4yg"},
		{"min tick", -MAX_TICK, "0000000"},
		{"large positive", 500000, "001aar8"},
		{"large negative", -500000, "000bt68"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := EncodeTickKey(tt.tick)
			uassert.Equal(t, tt.want, got)
			uassert.Equal(t, 7, len(got))
		})
	}
}

func TestDecodeTickKey(t *testing.T) {
	tests := []struct {
		name    string
		encoded string
		want    int32
	}{
		{"zero tick", "000v2f8", 0},
		{"positive tick", "000v2jc", 100},
		{"negative tick", "000v2c4", -100},
		{"max tick", "001p4yg", MAX_TICK},
		{"min tick", "0000000", -MAX_TICK},
		{"large positive", "001aar8", 500000},
		{"large negative", "000bt68", -500000},
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
		t.Run(tt.name, func(t *testing.T) {
			got := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestParsePoolPath(t *testing.T) {
	tests := []struct {
		name      string
		poolPath  string
		wantToken0 string
		wantToken1 string
		wantFee    uint32
	}{
		{
			name:      "valid pool path",
			poolPath:  "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
			wantToken0: "gno.land/r/onbloc/bar",
			wantToken1: "gno.land/r/onbloc/foo",
			wantFee:    500,
		},
		{
			name:      "fee 3000",
			poolPath:  "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000",
			wantToken0: "gno.land/r/onbloc/bar",
			wantToken1: "gno.land/r/onbloc/qux",
			wantFee:    3000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			token0, token1, fee := ParsePoolPath(tt.poolPath)
			uassert.Equal(t, tt.wantToken0, token0)
			uassert.Equal(t, tt.wantToken1, token1)
			uassert.Equal(t, tt.wantFee, fee)
		})
	}
}
