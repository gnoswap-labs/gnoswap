package gnoswap

import "gno.land/p/demo/ufmt"

func tickBitmapPosition(tick bigint) (bigint, bigint) {
	wordPos := (tick / 256) // tick >> 8
	bitPos := (tick % 256)
	if bitPos < 0 {
		bitPos = -bitPos
	}

	requireUnsigned(bitPos, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapPosition() || bitPos(%s) > 0", bitPos))
	return wordPos, bitPos
}

func (pool *Pool) tickBitmapFlipTick(
	tick bigint,
	tickSpacing bigint,
) {
	require(tick%tickSpacing == 0, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || tick MOD tickSpacing(%s) != 0", tick%tickSpacing))
	wordPos, bitPos := tickBitmapPosition(tick)
	mask := bigint(1) << uint64(bitPos)
	requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || mask(%s) > 0", mask))

	pool.tickBitmaps[wordPos] ^= mask
}

func (pool *Pool) tickBitmapNextInitializedTickWithInOneWord(
	tick bigint,
	tickSpacing bigint,
	zeroForOne bool,
) (bigint, bool) {
	compress := bigint(tick / tickSpacing)
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
			return (compress -
					bigint(
						bigint(bitPos-bitMathMostSignificantBit(masked)),
					)) * tickSpacing,
				initialized
		}
		return (compress - bigint(bitPos)) * tickSpacing, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	// check zero
	var mask bigint
	if bitPos == 0 {
		mask = MAX_UINT256 - bigint(1)
	} else {
		mask = MAX_UINT256 - (bigint(1) << uint64(bigint(bitPos)-bigint(1)))
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
		return (compress +
			1 +
			bigint(
				bigint((bitMathLeastSignificantBit(masked) - bitPos)),
			)) * tickSpacing, initialized
	}

	return (compress +
		1 +
		bigint(
			bigint((MAX_UINT8 - bitPos)))) * tickSpacing, initialized
}
