package gnoswap

import (
	"math"
	"internal/big"
)


// bitPos should be unsigned
func TickBitmapPosition(tick bigint) (bigint, bigint) {
	wordPos := (tick / 256) // tick >> 8
	bitPos := (tick % 256)
	return wordPos, bitPos
}


func TickBitmapFlipTick(
	tick bigint,
	tickSpacing bigint,
) {
	require(tick % tickSpacing == 0, "TICK_SPACING")
	wordPos, bitPos := TickBitmapPosition(tick)
	// mask := 1 << bitPos
	mask := bigint(big.Pow(2, bigdec(bitPos)))
	tickBitmaps[wordPos] ^= mask
}

func TickBitmapNextInitializedTickWithInOneWord(
	tick bigint,
	tickSpacing bigint,
	zeroForOne bool,
) (bigint, bool) {
	compress := bigint(tick / tickSpacing)
	if tick < 0 && tick % tickSpacing != 0 {
		compress--
	}

	if zeroForOne {
		wordPos, bitPos := TickBitmapPosition(compress)
		// mask := (1 << bitPos) - 1 + (1 << bitPos)
		mask := bigint( big.Pow(2, bigdec(bitPos)) - 1 + big.Pow(2, bigdec(bitPos)) )
		masked := tickBitmaps[wordPos] & mask 

		initialized := masked != 0

		if initialized { 
			return (
				compress - 
				bigint(
					bigint(bitPos - BitMathMostSignificantBit(masked)),
				)) * tickSpacing, 
				initialized
		}
		return (compress - bigint(bitPos)) * tickSpacing, initialized
	}

	wordPos, bitPos := TickBitmapPosition(compress + 1)	
	// mask := ~((1 << bitPos) - 1)
	mask := big.Not( bigint( (big.Pow(2, bigdec(bitPos))) - 1) )
	masked := tickBitmaps[wordPos] & mask

	initialized := masked != 0
	if initialized {
		return (
			compress + 
			1 + 
			bigint(
				bigint((BitMathLeastSignificantBit(masked) - bitPos)),
			)) * tickSpacing, initialized
	}

	return (
		compress + 
		1 + 
		bigint(
			bigint((MAX_UINT8 - bitPos)))) * tickSpacing, initialized
}