package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/consts"

	plp "gno.land/p/gnoswap/pool"

	u256 "gno.land/p/gnoswap/uint256"
)

func tickBitmapPosition(tick int32) (int16, uint8) {
	wordPos := int16(tick >> 8) // tick / 256
	bitPos := uint8(tick % 256)

	return wordPos, bitPos
}

func (pool *Pool) tickBitmapFlipTick(
	tick int32,
	tickSpacing int32,
) {
	if tick%tickSpacing != 0 {
		panic(ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || tick(%d) MOD tickSpacing(%d) != 0(%d)", tick, tickSpacing, tick%tickSpacing))
	}

	wordPos, bitPos := tickBitmapPosition(tick / tickSpacing)

	// 1 << bitPos
	mask := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))

	pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()
	pool.tickBitmaps[wordPos] = new(u256.Uint).Xor(pool.tickBitmaps[wordPos], mask)
}

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

		// mask := (1 << bitPos) - 1 + (1 << bitPos)
		shift1LeftByBitPos := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))

		mask := shift1LeftByBitPos.Clone()
		mask = new(u256.Uint).Sub(mask, u256.NewUint(1))
		mask = new(u256.Uint).Add(mask, shift1LeftByBitPos.Clone())

		pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()
		masked := new(u256.Uint).And(pool.tickBitmaps[wordPos], mask)

		initialized := !(masked.IsZero())

		if initialized {
			next := (compress - int32(bitPos-plp.BitMathMostSignificantBit(masked))) * tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	shift1LeftByBitPos := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))
	_mask := shift1LeftByBitPos.Clone()
	_mask = new(u256.Uint).Sub(_mask, u256.NewUint(1))
	mask := bitwiseNotForUint256BitmapIndexing(_mask)

	pool.tickBitmaps[wordPos] = pool.tickBitmaps[wordPos].NilToZero()
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

func bitwiseNotForUint256BitmapIndexing(x *u256.Uint) *u256.Uint {
	// REF: https://stackoverflow.com/a/77071037

	// Create a mask with all bits set to 1
	mask := u256.MustFromDecimal(consts.MAX_UINT256)
	mask = new(u256.Uint).Sub(mask, u256.NewUint(1))

	// XOR with mask to perform bitwise NOT
	// result := x ^ mask

	result := new(u256.Uint).Xor(x, mask)
	return result
}
