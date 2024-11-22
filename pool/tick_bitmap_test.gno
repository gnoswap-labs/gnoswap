package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestTickBitmapPosition(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		wantWordPos int16
		wantBitPos  uint8
	}{
		{
			name:        "positive tick",
			tick:        300,
			wantWordPos: 1,  // 300 >> 8 = 1
			wantBitPos:  44, // 300 % 256 = 44
		},
		{
			name:        "negative tick",
			tick:        -300,
			wantWordPos: -2,  // -300 >> 8 = -2
			wantBitPos:  212, // -300 % 256 = 212
		},
		{
			name:        "zero tick",
			tick:        0,
			wantWordPos: 0,
			wantBitPos:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			wordPos, bitPos := tickBitmapPosition(tt.tick)
			if wordPos != tt.wantWordPos {
				t.Errorf("wordPos = %v, want %v", wordPos, tt.wantWordPos)
			}
			if bitPos != tt.wantBitPos {
				t.Errorf("bitPos = %v, want %v", bitPos, tt.wantBitPos)
			}
		})
	}
}

func TestTickBitmapFlipTick(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		shouldPanic bool
	}{
		{
			name:        "valid tick and spacing",
			tick:        100,
			tickSpacing: 20,
			shouldPanic: false,
		},
		{
			name:        "invalid tick and spacing",
			tick:        101,
			tickSpacing: 20,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := &Pool{
				tickBitmaps: make(map[int16]*u256.Uint),
			}

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but got none")
					}
				}()
			}

			pool.tickBitmapFlipTick(tt.tick, tt.tickSpacing)

			if !tt.shouldPanic {
				wordPos, bitPos := tickBitmapPosition(tt.tick / tt.tickSpacing)
				expected := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))
				if pool.tickBitmaps[wordPos].Cmp(expected) != 0 {
					t.Errorf("bitmap not set correctly")
				}
			}
		})
	}
}

func TestTickBitmapNextInitializedTickWithInOneWord(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		lte         bool
		setupBitmap func(*Pool)
		wantTick    int32
		wantInit    bool
	}{
		{
			name:        "search lte with initialized tick",
			tick:        200,
			tickSpacing: 20,
			lte:         true,
			setupBitmap: func(p *Pool) {
				p.tickBitmapFlipTick(180, 20) // Initialize a tick at 180
			},
			wantTick: 180,
			wantInit: true,
		},
		{
			name:        "search gt with initialized tick",
			tick:        100,
			tickSpacing: 20,
			lte:         false,
			setupBitmap: func(p *Pool) {
				p.tickBitmapFlipTick(140, 20) // Initialize a tick at 140
			},
			wantTick: 140,
			wantInit: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := &Pool{
				tickBitmaps: make(map[int16]*u256.Uint),
			}
			if tt.setupBitmap != nil {
				tt.setupBitmap(pool)
			}

			gotTick, gotInit := pool.tickBitmapNextInitializedTickWithInOneWord(
				tt.tick,
				tt.tickSpacing,
				tt.lte,
			)

			if gotTick != tt.wantTick {
				t.Errorf("tick = %v, want %v", gotTick, tt.wantTick)
			}
			if gotInit != tt.wantInit {
				t.Errorf("initialized = %v, want %v", gotInit, tt.wantInit)
			}
		})
	}
}

func TestGenerateFullMaskForBitPos(t *testing.T) {
	tests := []struct {
		name     string
		bitPos   uint
		expected string // decimal string representation
	}{
		{
			name:     "bit position 0",
			bitPos:   0,
			expected: "1",
		},
		{
			name:     "bit position 1",
			bitPos:   1,
			expected: "3",
		},
		{
			name:     "bit position 4",
			bitPos:   4,
			expected: "31",
		},
		{
			name:     "bit position 8",
			bitPos:   8,
			expected: "511",
		},
		{
			name:     "bit position 255",
			bitPos:   255,
			expected: "115792089237316195423570985008687907853269984665640564039457584007913129639935",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := generateFullMaskForBitPos(tt.bitPos)
			if result.ToString() != tt.expected { // Changed from Hex() to Dec()
				t.Errorf("generateFullMaskForBitPos(%d) = %s, want %s",
					tt.bitPos, result.Dec(), tt.expected)
			}
		})
	}
}

func TestGenerateMaskClearingBitsBelow(t *testing.T) {
	tests := []struct {
		name  string
		input uint
		want  string // expected decimal string
	}{
		{
			name:  "zero",
			input: 0,
			want:  "115792089237316195423570985008687907853269984665640564039457584007913129639935",
		},
		{
			name:  "small number",
			input: 5,
			want:  "115792089237316195423570985008687907853269984665640564039457584007913129639904",
		},
		{
			name:  "max uint(8)",
			input: 255,
			want:  "57896044618658097711785492504343953926634992332820282019728792003956564819968",
		},
		{
			name:  "max uint(16)",
			input: 65535,
			want:  "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			want := u256.MustFromDecimal(tt.want)

			got := generateMaskClearingBitsBelow(tt.input)

			if got.Cmp(want) != 0 {
				t.Errorf("generateMaskClearingBitsBelow() = %v, want %v", got.Dec(), want.Dec())
			}
		})
	}
}
