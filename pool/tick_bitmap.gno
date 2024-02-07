package pool

import (
	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/u256"
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
	require(tick%tickSpacing == 0, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || tick(%d) MOD tickSpacing(%d) != 0 (got:%d)", tick, tickSpacing, tick%tickSpacing))
	wordPos, bitPos := tickBitmapPosition(tick / tickSpacing)
	mask :=
		bigint(1) <<
			uint64(bitPos) // 2 ** bitPos
	mask := bigint(int64(1)) << uint64(bitPos) // 2 ** bitPos

	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || mask(%d) >= 0", mask))

	pool.tickBitmaps[wordPos] ^= mask
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

		mask := (bigint(1) << uint64(bitPos)) - bigint(1) + (bigint(1) << uint64(bitPos))
		requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #1 || mask(%d) >= 0", mask))

		masked := pool.tickBitmaps[wordPos] & mask
		requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #1 || masked(%d) >= 0", masked))

		initialized := masked != 0

		if initialized {
			next := (compress - int32(bitPos-bitMathMostSignificantBit(u256.FromBigint(mask)))) * tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	_mask := bigint(1) << uint64(bitPos)
	_mask -= bigint(1)
	mask := bigintBitwiseNotForUint256BitmapIndexing(_mask)
	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #2 || mask(%d) >= 0", mask))

	masked := pool.tickBitmaps[wordPos] & mask
	requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord #2 || masked(%d) >= 0", masked))

	initialized := masked != 0
	if initialized {
		next := (compress + 1 + int32(bitMathLeastSignificantBit(u256.FromBigint(masked))-bitPos)) * tickSpacing
		return next, initialized
	} else {
		next := (compress + 1 + int32(int64(consts.MAX_UINT8-bigint(uint64(bitPos))))) * tickSpacing
		return next, initialized
	}
}

func bigintBitwiseNotForUint256BitmapIndexing(x bigint) bigint {
	// REF: https://stackoverflow.com/a/77071037

	// Create a mask with all bits set to 1
	mask := consts.MAX_UINT256
	mask -= bigint(1)

	// XOR with mask to perform bitwise NOT
	result := x ^ mask
	return result
}
