package pool

import (
	"gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
	pl "gno.land/r/gnoswap/pool"
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
//   - p: Pool state whose tick bitmap is toggled.
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
func tickBitmapFlipTick(
	p *pl.Pool,
	tick int32,
	tickSpacing int32,
) {
	checkTickSpacing(tick, tickSpacing)
	wordPos, bitPos := tickBitmapPosition(tick / tickSpacing)

	mask := u256.Zero().Lsh(u256.One(), uint(bitPos))
	current := getTickBitmap(p, wordPos)
	next := u256.Zero().Xor(current, mask)
	if next.IsZero() {
		deleteTickBitmap(p, wordPos)
		return
	}

	setTickBitmap(p, wordPos, next)
}

// tickBitmapNextInitializedTickWithInOneWord finds the next initialized tick within
// one word of the bitmap.
//
// Parameters:
//   - p: Pool state containing the compressed tick bitmap.
//   - tick: Current tick from which the search starts.
//   - tickSpacing: Distance between valid ticks used to compress the search
//     coordinate.
//   - lte: True to search at or below the current compressed tick; false to
//     search above it.
//
// Returns:
//   - int32: Nearest tick boundary selected within the current bitmap word, or
//     the word edge when no initialized bit is present there.
//   - bool: True when the masked word contains at least one initialized bit.
func tickBitmapNextInitializedTickWithInOneWord(
	p *pl.Pool,
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
	masked := u256.Zero().And(getTickBitmap(p, wordPos), mask)
	initialized := !masked.IsZero()

	nextTick := getNextTick(lte, initialized, compress, bitPos, tickSpacing, masked)
	return nextTick, initialized
}

// getTickBitmap gets the tick bitmap for the given word position.
// Missing words are implicit zeroes.
//
// Parameters:
//   - p: Pool state containing the tick bitmap map.
//   - wordPos: Signed bitmap word position to read.
//
// Returns:
//   - *u256.Uint: Bitmap word as an unsigned 256-bit value; zero when wordPos
//     has no stored entry.
func getTickBitmap(p *pl.Pool, wordPos int16) *u256.Uint {
	value, exist := p.TickBitmaps()[wordPos]
	if !exist {
		return u256.Zero()
	}

	return u256.MustFromDecimal(value)
}

// setTickBitmap stores a bitmap word for the given word position.
//
// Parameters:
//   - p: Pool state whose tick bitmap map is updated.
//   - wordPos: Signed bitmap word position to write.
//   - tickBitmap: 256-bit bitmap value; each set bit denotes an initialized
//     compressed tick.
func setTickBitmap(p *pl.Pool, wordPos int16, tickBitmap *u256.Uint) {
	p.SetTickBitmap(wordPos, tickBitmap.ToString())
}

// deleteTickBitmap removes the bitmap word for a word position.
//
// Parameters:
//   - p: Pool state whose tick bitmap map is updated.
//   - wordPos: Signed bitmap word position to remove; removing an all-zero word
//     keeps the sparse bitmap compact.
func deleteTickBitmap(p *pl.Pool, wordPos int16) {
	p.DeleteTickBitmap(wordPos)
}

// tickBitmapPosition maps a compressed tick index to its signed bitmap word and
// bit offset within that word.
//
// Parameters:
//   - tick: Compressed tick index; arithmetic shifting groups 256 consecutive
//     indices into one word.
//
// Returns:
//   - int16: Signed bitmap word position, equivalent to tick divided by 256.
//   - uint8: Bit offset within the word, in the range 0 through 255.
func tickBitmapPosition(tick int32) (int16, uint8) {
	return int16(tick >> 8), uint8(tick) & bitMask8
}

// getWordAndBitPos computes the bitmap position used for a directional tick
// search.
//
// Parameters:
//   - tick: Compressed tick index at the current search boundary.
//   - lte: True for a search at-or-below tick; false increments tick before
//     mapping so the search begins strictly above it.
//
// Returns:
//   - int16: Signed bitmap word containing the directional search boundary.
//   - uint8: Bit offset of that boundary within the word.
func getWordAndBitPos(tick int32, lte bool) (int16, uint8) {
	if !lte {
		tick++
	}
	return tickBitmapPosition(tick)
}

// getMaskBit builds the directional mask used to inspect candidate bits in one
// bitmap word.
//
// Parameters:
//   - bitPos: Bit offset of the current compressed tick within its word, from 0
//     through 255.
//   - lte: True to retain bits at or below bitPos; false to retain bits at or
//     above bitPos.
//
// Returns:
//   - *u256.Uint: 256-bit mask selecting the search interval for the requested
//     direction.
func getMaskBit(bitPos uint, lte bool) *u256.Uint {
	if lte {
		if bitPos == bitMask8 {
			return u256.Zero().SetAllOne()
		}
		return u256.Zero().Sub(u256.Zero().Lsh(u256.One(), bitPos+1), u256.One())
	}
	if bitPos == 0 {
		return u256.Zero().SetAllOne()
	}
	return u256.Zero().Not(u256.Zero().Sub(u256.Zero().Lsh(u256.One(), bitPos), u256.One()))
}

// getNextTick chooses the nearest candidate tick from the initialized or
// uninitialized branch of a directional bitmap search.
//
// Parameters:
//   - lte: True to search toward lower compressed ticks; false to search higher.
//   - initialized: True when masked contains an initialized bit.
//   - compress: Compressed current tick index.
//   - bitPos: Current bit offset within the bitmap word.
//   - tickSpacing: Distance between valid ticks.
//   - masked: Directionally masked bitmap word used when initialized is true.
//
// Returns:
//   - int32: Candidate tick index in pool tick units for the next swap step.
func getNextTick(lte, initialized bool, compress int32, bitPos uint8, tickSpacing int32, masked *u256.Uint) int32 {
	if initialized {
		return getTickIfInitialized(compress, tickSpacing, bitPos, masked, lte)
	}
	return getTickIfNotInitialized(compress, tickSpacing, bitPos, lte)
}

// getTickIfInitialized selects the nearest initialized compressed tick in the
// masked bitmap word.
//
// Parameters:
//   - compress: Compressed current tick index.
//   - tickSpacing: Distance between valid ticks.
//   - bitPos: Current bit offset within the word.
//   - masked: Non-zero directional mask containing initialized bits.
//   - lte: True to select the most-significant retained bit below or at bitPos;
//     false selects the least-significant retained bit above bitPos.
//
// Returns:
//   - int32: Initialized pool tick corresponding to the selected bitmap bit.
func getTickIfInitialized(compress, tickSpacing int32, bitPos uint8, masked *u256.Uint, lte bool) int32 {
	if lte {
		return (compress - int32(bitPos-gnsmath.BitMathMostSignificantBit(masked))) * tickSpacing
	}
	return (compress + 1 + int32(gnsmath.BitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
}

// getTickIfNotInitialized returns the edge tick for a bitmap word with no
// initialized bit in the requested direction.
//
// Parameters:
//   - compress: Compressed current tick index.
//   - tickSpacing: Distance between valid ticks.
//   - bitPos: Current bit offset within the word.
//   - lte: True to return the lower edge at or below bitPos; false to return
//     the upper edge after the current word.
//
// Returns:
//   - int32: Candidate pool tick at the directional edge of the current word.
func getTickIfNotInitialized(compress, tickSpacing int32, bitPos uint8, lte bool) int32 {
	if lte {
		return (compress - int32(bitPos)) * tickSpacing
	}
	return (compress + 1 + int32(bitMask8-bitPos)) * tickSpacing
}
