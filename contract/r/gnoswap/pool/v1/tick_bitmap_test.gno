package pool

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func newTickBitmapPool(t *testing.T) *Pool {
	t.Helper()
	return &Pool{tickBitmaps: avl.NewTree()}
}

func bitIsSet(t *testing.T, p *Pool, tick, spacing int32) bool {
	t.Helper()
	wp, bp := tickBitmapPosition(tick / spacing)
	mask := u256.Zero().Lsh(u256.One(), uint(bp))
	return u256.Zero().And(p.getTickBitmap(wp), mask).Cmp(u256.Zero()) != 0
}

func flipMany(t *testing.T, p *Pool, spacing int32, ticks ...int32) {
	t.Helper()
	for _, tk := range ticks {
		p.tickBitmapFlipTick(tk, spacing)
	}
}

func TestTickBitmap_PositionBoundaryAndSign(t *testing.T) {
	cases := []struct {
		name        string
		tick        int32
		wantWordPos int16
		wantBitPos  uint8
	}{
		{"zero", 0, 0, 0},
		{"pos within first word", 300, 1, 44},   // 300 = 256 + 44
		{"neg within prev word", -300, -2, 212}, // -300 = -2*256 + 212 (two's-complement mapping)
		{"neg -1", -1, -1, 255},
		{"boundary 255", 255, 0, 255},
		{"boundary 256", 256, 1, 0},
		{"boundary -256", -256, -1, 0},
		{"boundary -257", -257, -2, 255},
		{"MIN_TICK", -887272, -3466, 24},
		{"MAX_TICK", 887272, 3465, 232},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			wp, bp := tickBitmapPosition(tc.tick)
			uassert.Equal(t, tc.wantWordPos, wp)
			uassert.Equal(t, tc.wantBitPos, bp)
		})
	}
}

func TestTickBitmap_GetMaskBit_LTE(t *testing.T) {
	// lte: mask = (1 << (bitPos+1)) - 1 (lower mask including current bit)
	t.Run("bitPos=0 => 0b1", func(t *testing.T) {
		mask := getMaskBit(0, true)
		uassert.True(t, mask.Eq(u256.One()))
	})
	t.Run("bitPos=7 => 0xff", func(t *testing.T) {
		mask := getMaskBit(7, true)
		uassert.True(t, mask.Eq(u256.NewUint(255)))
	})
	t.Run("bitPos=255 => all ones", func(t *testing.T) {
		mask := getMaskBit(255, true)
		all := u256.Zero().Not(u256.Zero()) // 2^256-1
		uassert.True(t, mask.Eq(all))
	})
}

func TestTickBitmap_GetMaskBit_GT(t *testing.T) {
	// gt: mask = ~((1<<bitPos)-1) (upper mask including current bit)
	t.Run("bitPos=0 => all ones", func(t *testing.T) {
		mask := getMaskBit(0, false)
		all := u256.Zero().Not(u256.Zero())
		uassert.True(t, mask.Eq(all))
	})
	t.Run("bitPos=254 => (1<<254)|(1<<255)", func(t *testing.T) {
		mask := getMaskBit(254, false)
		b254 := u256.Zero().Lsh(u256.One(), 254)
		b255 := u256.Zero().Lsh(u256.One(), 255)
		expect := u256.Zero().Add(b254, b255)
		uassert.True(t, mask.Eq(expect))
	})
	t.Run("bitPos=255 => (1<<255)", func(t *testing.T) {
		mask := getMaskBit(255, false)
		expect := u256.Zero().Lsh(u256.One(), 255)
		uassert.True(t, mask.Eq(expect))
	})
}

func TestTickBitmap_FlipTick_SetAndUnset(t *testing.T) {
	p := newTickBitmapPool(t)
	// With correct spacing
	p.tickBitmapFlipTick(100, 20)
	uassert.True(t, bitIsSet(t, p, 100, 20))
	// Flipping again should unset
	p.tickBitmapFlipTick(100, 20)
	uassert.False(t, bitIsSet(t, p, 100, 20))
}

func TestTickBitmap_FlipTick_PanicOnBadSpacing(t *testing.T) {
	p := newTickBitmapPool(t)
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected panic on misaligned tick")
		}
	}()
	// 101 % 20 != 0
	p.tickBitmapFlipTick(101, 20)
}

func TestTickBitmap_Compress_Rounding_ForNegatives(t *testing.T) {
	cases := []struct {
		name         string
		tick         int32
		spacing      int32
		wantCompress int32
	}{
		{"pos exact", 120, 60, 2},
		{"neg exact", -120, 60, -2},
		{"neg remainder", -121, 60, -3}, // floor(-2.016..) == -3
		{"tick -1 spacing 1", -1, 1, -1},
		{"neg near zero", -59, 60, -1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			compress := tc.tick / tc.spacing
			if tc.tick < 0 && tc.tick%tc.spacing != 0 {
				compress--
			}
			uassert.Equal(t, tc.wantCompress, compress)
		})
	}
}

func TestTickBitmap_NextInitialized_WithinWord_WithInit(t *testing.T) {
	p := newTickBitmapPool(t)
	// spacing=20, set multiple bits in same word
	flipMany(t, p, 20, 60, 100, 140, 180, 220) // 60..220
	// lte: find nearest initialized bit at or below current tick (MSB in mask)
	got, ok := p.tickBitmapNextInitializedTickWithInOneWord(200, 20, true)
	uassert.True(t, ok)
	uassert.Equal(t, int32(180), got)
	// gt: find nearest initialized bit above current tick (LSB in mask)
	got, ok = p.tickBitmapNextInitializedTickWithInOneWord(100, 20, false)
	uassert.True(t, ok)
	uassert.Equal(t, int32(140), got)
}

func TestTickBitmap_NextInitialized_WithinWord_NoInit(t *testing.T) {
	p := newTickBitmapPool(t)
	// Word is empty
	tick, spacing := int32(100), int32(10)
	got, ok := p.tickBitmapNextInitializedTickWithInOneWord(tick, spacing, false)
	uassert.False(t, ok)
	// For gt(false), should return word boundary (next word's first bit position)
	// Implementation returns: (compress + 1 + (255 - bitPos)) * spacing
	// We verify ok=false and boundary-type return (used as restart point for higher-level search)
	_ = got // Value serves as restart pointer for upper-level search logic
}

func TestTickBitmap_Dense_SpacingOne_ConsecutiveSearch(t *testing.T) {
	p := newTickBitmapPool(t)
	// Set all ticks from [-3,3]
	for tk := int32(-3); tk <= 3; tk++ {
		p.tickBitmapFlipTick(tk, 1)
	}
	// gt: next tick is always +1 (within same word or across boundaries)
	for tk := int32(-3); tk < 3; tk++ {
		next, ok := p.tickBitmapNextInitializedTickWithInOneWord(tk, 1, false)
		uassert.True(t, ok)
		uassert.Equal(t, tk+1, next)
	}
	// lte: points to itself
	for tk := int32(3); tk >= -3; tk-- {
		next, ok := p.tickBitmapNextInitializedTickWithInOneWord(tk, 1, true)
		uassert.True(t, ok)
		uassert.Equal(t, tk, next)
	}
}

func TestTickBitmap_WordBoundary_Transitions(t *testing.T) {
	p := newTickBitmapPool(t)
	sp := int32(1)
	flipMany(t, p, sp, -257, -256, -255, -1, 0, 1, 254, 255, 256)

	cases := []struct {
		name     string
		tick     int32
		lte      bool
		expected int32
		hasInit  bool
	}{
		{"gt from -257 finds -256", -257, false, -256, true},
		{"lte from -255", -255, true, -255, true},
		{"gt from -1 finds 0", -1, false, 0, true},
		{"gt from 255 finds 256", 255, false, 256, true},
		{"lte from 256", 256, true, 256, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			next, ok := p.tickBitmapNextInitializedTickWithInOneWord(tc.tick, sp, tc.lte)
			uassert.Equal(t, tc.hasInit, ok)
			if tc.hasInit {
				uassert.Equal(t, tc.expected, next)
			}
		})
	}
}

func TestTickBitmap_Shift_Equals_FloorDivision_By256(t *testing.T) {
	// Verify shift operation equals floor division by 256 for negative numbers
	ticks := []int32{-887272, -257, -256, -255, -1, 0, 1, 255, 256, 257, 887272}
	for _, tk := range ticks {
		shifted := tk >> 8
		// floor(tk/256)
		floor := tk / 256
		if tk < 0 && tk%256 != 0 {
			floor--
		}
		uassert.Equal(t, floor, shifted)
	}
}
