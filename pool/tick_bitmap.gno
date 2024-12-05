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

	mask := new(u256.Uint).Lsh(u256.One(), uint(bitPos))
	pool.setTickBitmap(wordPos, new(u256.Uint).Xor(pool.getTickBitmap(wordPos), mask))
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

	wordPos, bitPos := getWordAndBitPos(compress, lte)
	mask := getMaskBit(uint(bitPos), lte)
	masked := new(u256.Uint).And(pool.getTickBitmap(wordPos), mask)
	initialized := !(masked.IsZero())

	nextTick := getNextTick(lte, initialized, compress, bitPos, tickSpacing, masked)
	return nextTick, initialized
}

// getTickBitmap gets the tick bitmap for the given word position
// if the tick bitmap is not initialized, initialize it to zero
func (pool *Pool) getTickBitmap(wordPos int16) *u256.Uint {
	if pool.tickBitmaps[wordPos] == nil {
		pool.tickBitmaps[wordPos] = u256.Zero()
	}

	return pool.tickBitmaps[wordPos]
}

// setTickBitmap sets the tick bitmap for the given word position
func (pool *Pool) setTickBitmap(wordPos int16, bitmap *u256.Uint) {
	pool.tickBitmaps[wordPos] = bitmap
}

// getWordAndBitPos gets tick's wordPos and bitPos depending on the swap direction
func getWordAndBitPos(tick int32, lte bool) (int16, uint8) {
	if lte {
		return tickBitmapPosition(tick)
	}

	tick++
	return tickBitmapPosition(tick)
}

// bMap is a map that maps boolean values to uint values.
// true maps to 1, and false maps to 0.
var bMap = map[bool]uint{
	true:  1,
	false: 0,
}

// getMaskBit generates a mask based on the provided bit position (bitPos) and a boolean flag (lte).
// The function constructs a bitmask with a shift depending on the bit position and the boolean value.
// It either returns the mask or its negation, based on the value of 'lte' (swap direction).
func getMaskBit(bitPos uint, lte bool) *u256.Uint {
	// Shift the number 1 to the left by (bitPos + bMap[lte]) positions.
	// If lte is true, the shift will be bitPos + 1; if false, it will be just bitPos.
	shifted := new(u256.Uint).Lsh(u256.One(), bitPos+bMap[lte])

	// Subtract 1 from the shifted value to create a mask.
	mask := new(u256.Uint).Sub(shifted, u256.One())

	// If lte is false, return the negation of the mask.
	if !lte {
		return new(u256.Uint).Not(mask)
	}
	// Otherwise, return the mask itself.
	return mask
}

// getNextTick gets the next tick depending on the initialized state and the swap direction
func getNextTick(lte, initialized bool, compress int32, bitPos uint8, tickSpacing int32, masked *u256.Uint) int32 {
	if initialized {
		return getTickIfInitialized(compress, tickSpacing, bitPos, masked, lte)
	}

	return getTickIfNotInitialized(compress, tickSpacing, bitPos, lte)
}

// getTickIfInitialized gets the next tick if the tick bitmap is initialized
func getTickIfInitialized(compress, tickSpacing int32, bitPos uint8, masked *u256.Uint, lte bool) int32 {
	if lte {
		return (compress - int32(bitPos-plp.BitMathMostSignificantBit(masked))) * tickSpacing
	}

	return (compress + 1 + int32(plp.BitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
}

// getTickIfNotInitialized gets the next tick if the tick bitmap is not initialized
func getTickIfNotInitialized(compress, tickSpacing int32, bitPos uint8, lte bool) int32 {
	if lte {
		return (compress - int32(bitPos)) * tickSpacing
	}

	return (compress + 1 + int32(255-bitPos)) * tickSpacing
}
