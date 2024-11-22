package pool

import (
	"gno.land/p/demo/ufmt"

	plp "gno.land/p/gnoswap/pool"

	u256 "gno.land/p/gnoswap/uint256"
)

// tickBitmapPosition calculates the word and bit position for a given tick
func tickBitmapPosition(tick int32) (int16, uint8) {
	wordPos := int16(tick >> 8) // tick / 256
	bitPos := uint8(tick % 256)

	return wordPos, bitPos
}

// tickBitmapFlipTick flips tthe bit corresponding to the given tick
// in the pool's tick bitmap.
func (pool *Pool) tickBitmapFlipTick(
	tick int32,
	tickSpacing int32,
) {
	if tick%tickSpacing != 0 {
		panic(addDetailToError(
			errInvalidTickAndTickSpacing,
			ufmt.Sprintf("tick_bitmap.gno__tickBitmapFlipTick() || tick(%d) MOD tickSpacing(%d) != 0(%d)", tick, tickSpacing, tick%tickSpacing),
		))
	}

	wordPos, bitPos := tickBitmapPosition(tick / tickSpacing)
	pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()

	mask := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))
	pool.tickBitmaps[wordPos] = new(u256.Uint).Xor(pool.tickBitmaps[wordPos], mask)
}

// tickBitmapNextInitializedTickWithInOneWord finds the next initialized tick within
// one word of the bitmap.
func (pool *Pool) tickBitmapNextInitializedTickWithInOneWord(
	tick int32,
	tickSpacing int32,
	lte bool,
) (int32, bool) {
	compress := tick / tickSpacing
	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	if lte {
		wordPos, bitPos := tickBitmapPosition(compress)
		pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()

		mask := generateFullMaskForBitPos(uint(bitPos))
		masked := new(u256.Uint).And(pool.tickBitmaps[wordPos], mask)

		// if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
		initialized := !(masked.IsZero())

		// overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
		if initialized {
			next := (compress - int32(bitPos-plp.BitMathMostSignificantBit(masked))) * tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)
	pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()

	mask := generateMaskClearingBitsBelow(uint(bitPos))
	masked := new(u256.Uint).And(pool.tickBitmaps[wordPos], mask)

	initialized := !(masked.IsZero())
	if initialized {
		next := (compress + 1 + int32(plp.BitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
		return next, initialized
	} else {
		next := (compress + 1 + int32(255-bitPos)) * tickSpacing

		return next, initialized
	}
}

func generateFullMaskForBitPos(bitPos uint) *u256.Uint {
	// 1 << bitPos
	one := u256.NewUint(1)
	shifted := new(u256.Uint).Lsh(one, bitPos)

	// (1 << bitPos) - 1
	minusOne := new(u256.Uint).Sub(shifted, u256.NewUint(1))

	// (1 << bitPos) - 1 + (1 << bitPos)
	result := new(u256.Uint).Add(minusOne, shifted)

	return result
}

func generateMaskClearingBitsBelow(bitPos uint) *u256.Uint {
	// 1 << bitPos
	one := u256.NewUint(1)
	shifted := new(u256.Uint).Lsh(one, bitPos)

	// (1 << bitPos) - 1
	minusOne := new(u256.Uint).Sub(shifted, u256.NewUint(1))

	// ~((1 << bitPos) - 1)
	mask := new(u256.Uint).Not(minusOne)

	return mask
}
