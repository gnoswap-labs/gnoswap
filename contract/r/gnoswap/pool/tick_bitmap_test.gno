package pool

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"
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
			name:        "zero tick",
			tick:        0,
			wantWordPos: 0,
			wantBitPos:  0,
		},
		{
			name:        "positive tick",
			tick:        300,
			wantWordPos: 1,
			wantBitPos:  44,
		},
		{
			name:        "negative tick",
			tick:        -300,
			wantWordPos: -2,
			wantBitPos:  212,
		},
		{
			name:        "negative one",
			tick:        -1,
			wantWordPos: -1,
			wantBitPos:  255,
		},
		{
			name:        "boundary 255",
			tick:        255,
			wantWordPos: 0,
			wantBitPos:  255,
		},
		{
			name:        "boundary 256",
			tick:        256,
			wantWordPos: 1,
			wantBitPos:  0,
		},
		{
			name:        "boundary -256",
			tick:        -256,
			wantWordPos: -1,
			wantBitPos:  0,
		},
		{
			name:        "boundary -257",
			tick:        -257,
			wantWordPos: -2,
			wantBitPos:  255,
		},
		{
			name:        "MIN_TICK",
			tick:        -887272,
			wantWordPos: -3466,
			wantBitPos:  24,
		},
		{
			name:        "MAX_TICK",
			tick:        887272,
			wantWordPos: 3465,
			wantBitPos:  232,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			wp, bp := tickBitmapPosition(tt.tick)
			uassert.Equal(t, tt.wantWordPos, wp)
			uassert.Equal(t, tt.wantBitPos, bp)
		})
	}
}

func TestGetMaskBit(t *testing.T) {
	tests := []struct {
		name     string
		bitPos   uint
		lte      bool
		validate func(*u256.Uint) bool
	}{
		{
			name:   "lte bitPos 0",
			bitPos: 0,
			lte:    true,
			validate: func(mask *u256.Uint) bool {
				return mask.Eq(u256.One())
			},
		},
		{
			name:   "lte bitPos 7",
			bitPos: 7,
			lte:    true,
			validate: func(mask *u256.Uint) bool {
				return mask.Eq(u256.NewUint(255))
			},
		},
		{
			name:   "lte bitPos 255",
			bitPos: 255,
			lte:    true,
			validate: func(mask *u256.Uint) bool {
				expected := new(u256.Uint).Sub(new(u256.Uint).Lsh(u256.One(), 256), u256.One())
				return mask.Eq(expected)
			},
		},
		{
			name:   "gt bitPos 0",
			bitPos: 0,
			lte:    false,
			validate: func(mask *u256.Uint) bool {
				allBits := new(u256.Uint).Not(u256.Zero())
				return mask.Eq(allBits)
			},
		},
		{
			name:   "gt bitPos 254",
			bitPos: 254,
			lte:    false,
			validate: func(mask *u256.Uint) bool {
				bit254 := new(u256.Uint).Lsh(u256.One(), 254)
				bit255 := new(u256.Uint).Lsh(u256.One(), 255)
				expected := new(u256.Uint).Add(bit254, bit255)
				return mask.Eq(expected)
			},
		},
		{
			name:   "gt bitPos 255",
			bitPos: 255,
			lte:    false,
			validate: func(mask *u256.Uint) bool {
				expected := new(u256.Uint).Lsh(u256.One(), 255)
				return mask.Eq(expected)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mask := getMaskBit(tt.bitPos, tt.lte)
			if !tt.validate(mask) {
				t.Errorf("Mask validation failed for bitPos=%d, lte=%v", tt.bitPos, tt.lte)
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
			name:        "valid positive tick",
			tick:        100,
			tickSpacing: 20,
			shouldPanic: false,
		},
		{
			name:        "valid negative tick",
			tick:        -300,
			tickSpacing: 20,
			shouldPanic: false,
		},
		{
			name:        "invalid tick spacing",
			tick:        101,
			tickSpacing: 20,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := &Pool{
				tickBitmaps: avl.NewTree(),
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
				expected := new(u256.Uint).Lsh(u256.One(), uint(bitPos))
				if pool.getTickBitmap(wordPos).Cmp(expected) != 0 {
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
				p.tickBitmapFlipTick(180, 20)
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
				p.tickBitmapFlipTick(140, 20)
			},
			wantTick: 140,
			wantInit: true,
		},
		{
			name:        "empty bitmap gt search",
			tick:        100,
			tickSpacing: 10,
			lte:         false,
			setupBitmap: nil,
			wantTick:    2550,
			wantInit:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := &Pool{
				tickBitmaps: avl.NewTree(),
			}
			if tt.setupBitmap != nil {
				tt.setupBitmap(pool)
			}

			gotTick, gotInit := pool.tickBitmapNextInitializedTickWithInOneWord(
				tt.tick,
				tt.tickSpacing,
				tt.lte,
			)

			uassert.Equal(t, tt.wantInit, gotInit)
			if tt.wantInit {
				uassert.Equal(t, tt.wantTick, gotTick)
			}
		})
	}
}

func TestTickBitmapCompressRounding(t *testing.T) {
	tests := []struct {
		name         string
		tick         int32
		tickSpacing  int32
		wantCompress int32
	}{
		{
			name:         "positive exact division",
			tick:         120,
			tickSpacing:  60,
			wantCompress: 2,
		},
		{
			name:         "negative exact division",
			tick:         -120,
			tickSpacing:  60,
			wantCompress: -2,
		},
		{
			name:         "negative with remainder",
			tick:         -121,
			tickSpacing:  60,
			wantCompress: -3,
		},
		{
			name:         "tick -1 spacing 1",
			tick:         -1,
			tickSpacing:  1,
			wantCompress: -1,
		},
		{
			name:         "negative near zero",
			tick:         -59,
			tickSpacing:  60,
			wantCompress: -1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			compress := tt.tick / tt.tickSpacing
			if tt.tick < 0 && tt.tick%tt.tickSpacing != 0 {
				compress--
			}
			uassert.Equal(t, tt.wantCompress, compress)
		})
	}
}

func TestDenseSpacing_SpacingOne(t *testing.T) {
	p := &Pool{tickBitmaps: avl.NewTree()}

	for tick := int32(-3); tick <= 3; tick++ {
		p.tickBitmapFlipTick(tick, 1)
	}

	for tick := int32(-3); tick < 3; tick++ {
		next, init := p.tickBitmapNextInitializedTickWithInOneWord(tick, 1, false)
		uassert.True(t, init)
		uassert.Equal(t, tick+1, next)
	}

	for tick := int32(3); tick >= -3; tick-- {
		next, init := p.tickBitmapNextInitializedTickWithInOneWord(tick, 1, true)
		uassert.True(t, init)
		uassert.Equal(t, tick, next)
	}
}

func TestWordBoundaryTransitions(t *testing.T) {
	p := &Pool{tickBitmaps: avl.NewTree()}

	boundaryTicks := []int32{
		-257, -256, -255,
		-1, 0, 1,
		254, 255, 256,
	}

	spacing := int32(1)
	for _, tick := range boundaryTicks {
		p.tickBitmapFlipTick(tick, spacing)
	}

	tests := []struct {
		name     string
		tick     int32
		lte      bool
		expected int32
		hasInit  bool
	}{
		{
			name:     "gt from -257 finds -256",
			tick:     -257,
			lte:      false,
			expected: -256,
			hasInit:  true,
		},
		{
			name:     "lte from -255",
			tick:     -255,
			lte:      true,
			expected: -255,
			hasInit:  true,
		},
		{
			name:     "gt from -1 finds 0",
			tick:     -1,
			lte:      false,
			expected: 0,
			hasInit:  true,
		},
		{
			name:     "gt from 255 finds 256",
			tick:     255,
			lte:      false,
			expected: 256,
			hasInit:  true,
		},
		{
			name:     "lte from 256",
			tick:     256,
			lte:      true,
			expected: 256,
			hasInit:  true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			next, init := p.tickBitmapNextInitializedTickWithInOneWord(tc.tick, spacing, tc.lte)

			uassert.Equal(t, tc.hasInit, init)
			if tc.hasInit {
				uassert.Equal(t, tc.expected, next)
			}
		})
	}
}

func TestShiftEqualsFloorDivision(t *testing.T) {
	ticks := []int32{
		-887272, -257, -256, -255, -1,
		0, 1, 255, 256, 257, 887272,
	}
	for _, tick := range ticks {
		got := tick >> 8

		want := tick / 256
		if tick < 0 && tick%256 != 0 {
			want--
		}

		if got != want {
			t.Errorf("tick=%d: shifted=%d, floorDiv=%d", tick, got, want)
		}
	}
}
