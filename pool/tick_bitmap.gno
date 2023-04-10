package gnoswap

import (
	"internal/big"
)


func TickBitmapPosition(tick bigint) (bigint, bigint) {
	wordPos := tick / 256
	bitPos := tick % 256
	return wordPos, bitPos
}


func TickBitmapFlipTick(
	tick bigint, // uint64
	tickSpacing bigint, // uint8
) {
	require(tick % tickSpacing == 0, "BAD#7")
	
	wordPos, bitPos := TickBitmapPosition(tick / tickSpacing)
	// 1 << bitPos == Pow(2, bitPos)
	// mask := 1 << bitPos // panic: untyped Bigint conversion should not happen during interpretation
	mask := big.Pow(2, bigdec(bitPos))
	
	// tickBitmap.Set(wordPos, tickBitmap.Get(wordPos) ^ mask)	
	oldPos, ok := tickBitmap.Get(string(wordPos))

	// XXX
	// require(ok, "old WordPos not found")
	if !ok {
		tickBitmap.Set(string(wordPos), 0 ^ bigint(mask))
	}
}

func TickNextInitializedTickWithInOneWord(
	tick bigint,
	tickSpacing bigint,
	lte bool
) (bigint, bool) {
	compress := tick / tickSpacing
	if tick < 0 && tick & tickSpacing != 0 {
		compress--
	}

	if lte {
		wordPos, bitPos := position(compress)
		mask : = big.Pow(2, bitPos) - 1 + big.Pow(2, bitPos)
		self, ok := tickBitmap.Get(string(wordPos))
		masked := self & mask

		initialized := masked != 0
		if initialized { 
			return (compress - bitPos - mostSignificantBit(masked)) * tickSpacing, initialized
		}
		return (compress - bitPos) * tickSpacing, initialized
	}

	wordPos, bitPos := position(compress)
	mask := big.Pow(2, bitPos) - 1
	self, ok := tickBitmap.Get(string(wordPos))
	masked := self & mask

	initialized := masked != 0
	if initialized {
		return (compress + 1 + leastSignificantBit(masked) - bitPos) * tickSpacing, initialized
	}

	return (compress + 1 + MAX_UINT8 - bitPos) * tickSpacing, initialized
}