package pool

import (
	"gno.land/p/demo/ufmt"
)

func tickBitmapPosition(tick int32) (int16, uint8) {
	wordPos := int16(tick / 256) // tick >> 8
	bitPos := uint8(tick % 256)

	return wordPos, bitPos
}

func (pool *Pool) tickBitmapFlipTick(
	tick int32,
	tickSpacing int32,
) {
	require(tick%tickSpacing == 0, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || tick MOD tickSpacing(%d) != 0", tick%tickSpacing))
	wordPos, bitPos := tickBitmapPosition(tick)
	mask := bigint(1) << uint64(bitPos)
	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || mask(%s) > 0", mask))

	pool.tickBitmaps[wordPos] ^= mask
}

func (pool *Pool) tickBitmapNextInitializedTickWithInOneWord(
	tick int32,
	tickSpacing int32,
	zeroForOne bool,
) (int32, bool) {
	compress := tick / tickSpacing
	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	if zeroForOne {
		wordPos, bitPos := tickBitmapPosition(compress)

		mask := (bigint(1) << uint64(bitPos)) - bigint(1) + (bigint(1) << uint64(bitPos))
		requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__mask(%s) >= 0__#1", mask))

		masked := pool.tickBitmaps[wordPos] & mask
		requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__masked(%s) >= 0__#1", masked))

		initialized := masked != 0

		if initialized {
			next := compress - int32(bitPos-bitMathMostSignificantBit(masked))*tickSpacing
			return next, initialized
		}

		next := compress - int32(bitPos)*tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	// check zero
	var mask bigint
	if bitPos == 0 {
		mask = MAX_UINT256 - bigint(1)
	} else {
		mask = MAX_UINT256 - (bigint(1) << uint64(bigint(uint64(bitPos))-bigint(1)))
	}

	// mask := ^((bigint(1) << bitPos) - bigint(1)) // (2^256-1) - (2^bitPos-1)
	if mask < 0 {
		mask = -mask
	}
	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__mask(%s) >= 0__#2", mask))

	masked := pool.tickBitmaps[wordPos] & mask
	requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__masked(%s) >= 0__#2", masked))

	initialized := masked != 0
	if initialized {
		next := compress + 1 + int32((bitMathLeastSignificantBit(masked)-bitPos))*tickSpacing
		return next, initialized
	} else {
		next := compress + 1 + int32(int64(MAX_UINT8-bigint(uint64(bitPos))))*tickSpacing
		return next, initialized
	}
}
