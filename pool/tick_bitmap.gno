package gnoswap

import (
	f "gno.land/r/factory"
	"math"
)

const BigInt1 bigint = bigint(1)

func TickBitmapPosition(tick bigint) (bigint, bigint) {
	wordPos := (tick / 256) // tick >> 8
	bitPos := (tick % 256)
	if bitPos < 0 {
		bitPos = -bitPos
	}

	requireUnsigned(bitPos, "tick_bitmap.gno__TickBitmapPosition__bitPos")
	return wordPos, bitPos
}

func (pool *Pool) TickBitmapFlipTick(
	tick bigint,
	tickSpacing bigint,
) {
	require(tick%tickSpacing == 0, "tick %% tickSpacing != 0")
	wordPos, bitPos := TickBitmapPosition(tick)
	mask := BigInt1 << uint64(bitPos)
	requireUnsigned(mask, "tick_bitmap.gno__TickBitmapFlipTick__mask")
	// tickBitmaps[wordPos] ^= mask
	_tw, exists := pool.tickBitmaps.Get(string(wordPos)).(bigint)

	f.UpdateAvlTree(pool.tickBitmaps, string(wordPos), _tw^mask)
	// pool.tickBitmaps.Set(string(wordPos), _tw^mask)
}

func (pool *Pool) TickBitmapNextInitializedTickWithInOneWord(
	tick bigint,
	tickSpacing bigint,
	zeroForOne bool,
) (bigint, bool) {
	compress := bigint(tick / tickSpacing)
	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	if zeroForOne {
		wordPos, bitPos := TickBitmapPosition(compress)
		mask := (BigInt1 << uint64(bitPos)) - BigInt1 + (BigInt1 << uint64(bitPos))
		requireUnsigned(mask, "tick_bitmap.gno__TickBitmapNextInitializedTickWithInOneWord__mask #1")
		// masked := tickBitmaps[wordPos] & mask
		_tw, exists := pool.tickBitmaps.Get(string(wordPos)).(bigint)
		masked := _tw & mask
		requireUnsigned(masked, "tick_bitmap.gno__TickBitmapNextInitializedTickWithInOneWord__masked #1")

		initialized := masked != 0

		if initialized {
			return (compress -
					bigint(
						bigint(bitPos-BitMathMostSignificantBit(masked)),
					)) * tickSpacing,
				initialized
		}
		return (compress - bigint(bitPos)) * tickSpacing, initialized
	}

	wordPos, bitPos := TickBitmapPosition(compress + 1)

	// check zero
	var mask bigint
	if bitPos == 0 {
		mask = MAX_UINT256 - bigint(1)
	} else {
		mask = MAX_UINT256 - (bigint(1) << uint64(bigint(bitPos)-bigint(1)))
	}

	// mask := ^((BigInt1 << bitPos) - BigInt1) // (2^256-1) - (2^bitPos-1)
	if mask < 0 {
		mask = -mask
	}

	requireUnsigned(mask, "tick_bitmap.gno__TickBitmapNextInitializedTickWithInOneWord__mask #2")
	// masked := tickBitmaps[wordPos] & mask
	_tw, exists := pool.tickBitmaps.Get(string(wordPos)).(bigint)
	masked := _tw & mask
	requireUnsigned(masked, "tick_bitmap.gno__TickBitmapNextInitializedTickWithInOneWord__masked #2")

	initialized := masked != 0
	if initialized {
		return (compress +
			1 +
			bigint(
				bigint((BitMathLeastSignificantBit(masked) - bitPos)),
			)) * tickSpacing, initialized
	}

	return (compress +
		1 +
		bigint(
			bigint((MAX_UINT8 - bitPos)))) * tickSpacing, initialized
}
