package pool

import (
	"strconv"

	"gno.land/p/nt/ufmt"
	plp "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
)

// bitMask8 is used for efficient modulo 256 operations
const bitMask8 = 0xff // 256 - 1

// tickBitmapFlipTick flips the state of a tick in the tick bitmap.
//
// This function toggles the "initialized" state of a tick in the tick bitmap.
// It ensures that the tick aligns with the specified tick spacing and then
// flips the corresponding bit in the bitmap representation.
//
// Parameters:
//   - tick: int32, the tick index to toggle.
//   - tickSpacing: int32, the spacing between valid ticks.
//     The tick must align with this spacing.
//
// Workflow:
//  1. Validates that the `tick` aligns with `tickSpacing` using `checkTickSpacing`.
//  2. Computes the position of the bit in the tick bitmap:
//     - `wordPos`: Determines which word in the bitmap contains the bit.
//     - `bitPos`: Identifies the position of the bit within the word.
//  3. Creates a bitmask using `Lsh` (Left Shift) to target the bit at `bitPos`.
//  4. Toggles (flips) the bit using XOR with the current value of the tick bitmap.
//  5. Updates the tick bitmap with the modified word.
//
// Behavior:
//   - If the bit is `0` (uninitialized), it will be flipped to `1` (initialized).
//   - If the bit is `1` (initialized), it will be flipped to `0` (uninitialized).
//
// Example:
//
//	pool.tickBitmapFlipTick(120, 60)
//	// This flips the bit for tick 120 with a tick spacing of 60.
//
// Notes:
//   - The `tick` must be divisible by `tickSpacing`. If not, the function will panic.
func (p *Pool) tickBitmapFlipTick(
	tick int32,
	tickSpacing int32,
) {
	checkTickSpacing(tick, tickSpacing)
	wordPos, bitPos := tickBitmapPosition(tick / tickSpacing)

	mask := u256.Zero().Lsh(u256.One(), uint(bitPos))
	current := p.getTickBitmap(wordPos)
	p.setTickBitmap(wordPos, u256.Zero().Xor(current, mask))
}

// tickBitmapNextInitializedTickWithInOneWord finds the next initialized tick within
// one word of the bitmap.
func (p *Pool) tickBitmapNextInitializedTickWithInOneWord(
	tick int32,
	tickSpacing int32,
	lte bool,
) (int32, bool) {
	compress := tick / tickSpacing
	// Round towards negative infinity for negative ticks
	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	wordPos, bitPos := getWordAndBitPos(compress, lte)
	mask := getMaskBit(uint(bitPos), lte)
	masked := u256.Zero().And(p.getTickBitmap(wordPos), mask)
	initialized := !masked.IsZero()

	nextTick := getNextTick(lte, initialized, compress, bitPos, tickSpacing, masked)
	return nextTick, initialized
}

// getTickBitmap gets the tick bitmap for the given word position
// if the tick bitmap is not initialized, initialize it to zero
func (p *Pool) getTickBitmap(wordPos int16) *u256.Uint {
	wordPosStr := strconv.Itoa(int(wordPos))

	value, exist := p.tickBitmaps.Get(wordPosStr)
	if !exist {
		p.initTickBitmap(wordPos)
		value, exist = p.tickBitmaps.Get(wordPosStr)
		if !exist {
			panic(newErrorWithDetail(
				errDataNotFound,
				ufmt.Sprintf("failed to initialize tickBitmap(%d)", wordPos),
			))
		}
	}

	bitmap, ok := value.(*u256.Uint)
	if !ok {
		panic(ufmt.Sprintf("failed to cast tickBitmap to *u256.Uint: %T", value))
	}
	return bitmap
}

// setTickBitmap sets the tick bitmap for the given word position
func (p *Pool) setTickBitmap(wordPos int16, tickBitmap *u256.Uint) {
	wordPosStr := strconv.Itoa(int(wordPos))
	p.tickBitmaps.Set(wordPosStr, tickBitmap)
}

// initTickBitmap initializes the tick bitmap for the given word position
func (p *Pool) initTickBitmap(wordPos int16) {
	p.setTickBitmap(wordPos, u256.Zero())
}

// tickBitmapPosition calculates the word and bit position for a given tick
func tickBitmapPosition(tick int32) (int16, uint8) {
	return int16(tick >> 8), uint8(tick) & bitMask8
}

// getWordAndBitPos gets tick's wordPos and bitPos depending on the swap direction
func getWordAndBitPos(tick int32, lte bool) (int16, uint8) {
	if !lte {
		tick++
	}
	return tickBitmapPosition(tick)
}

// getMaskBit generates a mask based on the provided bit position (bitPos) and a boolean flag (lte).
// The function constructs a bitmask with a shift depending on the bit position and the boolean value.
// It either returns the mask or its negation, based on the value of 'lte' (swap direction).
//
// NOTE: should always use a newly created `u256.One()` object.
func getMaskBit(bitPos uint, lte bool) *u256.Uint {
	if lte {
		if bitPos == bitMask8 {
			return u256.Zero().Not(u256.Zero()) // all ones
		}
		return u256.Zero().Sub(u256.Zero().Lsh(u256.One(), bitPos+1), u256.One())
	}
	if bitPos == 0 {
		return u256.Zero().Not(u256.Zero()) // all ones
	}
	return u256.Zero().Not(u256.Zero().Sub(u256.Zero().Lsh(u256.One(), bitPos), u256.One()))
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
	return (compress + 1 + int32(bitMask8-bitPos)) * tickSpacing
}
