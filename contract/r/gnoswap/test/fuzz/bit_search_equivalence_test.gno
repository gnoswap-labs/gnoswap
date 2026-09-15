package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/consts/v1"
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
)

// Test-only reference for the pre-#1441 shift searches. Keep independent of
// BitLen, math/bits, and production bit-search helpers. Inputs must be nonzero.
func legacyBitSearchMSB(x *u256.Uint) uint8 {
	temp := x.Clone()
	r := uint8(0)
	for _, shift := range []uint{128, 64, 32, 16, 8, 4, 2, 1} {
		threshold := new(u256.Uint).Lsh(u256.One(), shift)
		if temp.Gte(threshold) {
			temp.Rsh(temp, shift)
			r += uint8(shift)
		}
	}
	return r
}

func legacyBitSearchLSB(x *u256.Uint) uint8 {
	temp := x.Clone()
	r := uint8(255)
	for _, shift := range []uint{128, 64, 32, 16, 8, 4, 2, 1} {
		mask := new(u256.Uint).Lsh(u256.One(), shift)
		mask.Sub(mask, u256.One())
		if !new(u256.Uint).And(temp, mask).IsZero() {
			r -= uint8(shift)
		} else {
			temp.Rsh(temp, shift)
		}
	}
	return r
}

// Valid-input inverse from before #1441, with the original MSB shift search.
// The final forward-price check is unchanged by the optimization. Do not replace
// this reference with the production inverse: equality would become tautological.
func legacyBitSearchTick(price *u256.Uint) int32 {
	ratio := new(u256.Uint).Lsh(price, 32)
	msb := uint64(legacyBitSearchMSB(ratio))
	var r *u256.Uint
	if msb >= 128 {
		r = new(u256.Uint).Rsh(ratio, uint(msb-127))
	} else {
		r = new(u256.Uint).Lsh(ratio, uint(127-msb))
	}
	log2 := i256.NewInt(int64(msb) - 128)
	log2.Lsh(log2, 64)
	for i := 0; i < 14; i++ {
		squared, overflow := new(u256.Uint).MulOverflow(r, r)
		if overflow {
			panic("legacy tick square overflow")
		}
		r = squared.Rsh(squared, 127)
		f := new(u256.Uint).Rsh(r, 128)
		fraction := i256.FromUint256(f)
		fraction.Lsh(fraction, uint(63-i))
		log2.Or(log2, fraction)
		r.Rsh(r, uint(f.Uint64()))
	}
	logSqrt, overflow := new(i256.Int).MulOverflow(log2, i256.MustFromDecimal("255738958999603826347141"))
	if overflow {
		panic("legacy tick logarithm overflow")
	}
	low := new(i256.Int).Sub(logSqrt, i256.MustFromDecimal("3402992956809132418596140100660247210"))
	low.Rsh(low, 128)
	hi := new(i256.Int).Add(logSqrt, i256.MustFromDecimal("291339464771989622907027621153398088495"))
	hi.Rsh(hi, 128)
	lowTick, hiTick := int32(low.Int64()), int32(hi.Int64())
	if lowTick == hiTick || gnsmath.TickMathGetSqrtRatioAtTick(hiTick).Lte(price) {
		return hiTick
	}
	return lowTick
}

func TestFuzzBitSearch_LegacyEquivalence_Stateless(t *testing.T) {
	fuzz.CheckN(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T) {
		x := fuzz.Uint256().Draw(ft, "x").(*u256.Uint)
		// Random full-width values alone almost always select limbs 3/0.
		// Restrict width, then move the low bit across all four limbs.
		width := fuzz.IntRange(1, 256).Draw(ft, "width").(int)
		shift := fuzz.IntRange(0, 256-width).Draw(ft, "shift").(int)
		x.Rsh(x, uint(256-width))
		x.Or(x, u256.One())
		x.Lsh(x, uint(shift))
		original := x.Clone()
		wantMSB, wantLSB := legacyBitSearchMSB(x), legacyBitSearchLSB(x)
		gotMSB, gotLSB := gnsmath.BitMathMostSignificantBit(x), gnsmath.BitMathLeastSignificantBit(x)
		if gotMSB != wantMSB || gotLSB != wantLSB || !x.Eq(original) {
			ft.Fatalf("x=%s: MSB %d != %d, LSB %d != %d, preserved=%t", original.ToString(), gotMSB, wantMSB, gotLSB, wantLSB, x.Eq(original))
		}
	})
}

func TestFuzzTickMath_LegacyBitSearchEquivalence_Stateless(t *testing.T) {
	fuzz.CheckN(t, FUZZ_ITERATIONS_EXTENDED, func(ft *fuzz.T) {
		// Stratify by bit width rather than concentrating near the upper bound.
		bit := fuzz.IntRange(32, 159).Draw(ft, "price_bit").(int)
		lower := new(u256.Uint).Lsh(u256.One(), uint(bit))
		upper := new(u256.Uint).Lsh(u256.One(), uint(bit+1))
		if lower.Lt(consts.MinSqrtRatio()) {
			lower = consts.MinSqrtRatio()
		}
		if upper.Gt(consts.MaxSqrtRatio()) {
			upper = consts.MaxSqrtRatio()
		}
		upper.Sub(upper, u256.One())
		price := fuzz.Uint256Range(lower.ToString(), upper.ToString()).Draw(ft, "price").(*u256.Uint)
		original := price.Clone()
		want := legacyBitSearchTick(price)
		got := gnsmath.TickMathGetTickAtSqrtRatio(price)
		if got != want || !price.Eq(original) {
			ft.Fatalf("price=%s: tick %d != legacy %d, preserved=%t", original.ToString(), got, want, price.Eq(original))
		}
	})
}
