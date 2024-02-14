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
	mask := u256.NewUint(1)
	mask.Lsh(mask, uint(bitPos)) // 2 ** bitPos

	//XXXXXXXXXXXXXXXX
	// mask.Lsh is exptected to check overflow with the signed integer type.
	// Lets add an overflow proteced shift method for Uint so we dont have to make it a signed integer.
	// not implemented, should be done in a separate pr

	//requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || mask(%d) > 0", mask))

	pool.tickBitmaps[wordPos].Xor(pool.tickBitmaps[wordPos], mask)
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

		mask := new(u256.Uint).Lsh(u256.One(), uint(bitPos))
		mask.Sub(mask, u256.One())
		mask.Add(mask, (new(u256.Uint).Lsh(u256.One(), uint(bitPos))))
		// XXXXXXXX overflow check Lsh!
		// requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__mask(%d) >= 0__#1", mask))

		masked := new(u256.Uint).And(pool.tickBitmaps[wordPos], mask)

		initialized := !masked.IsZero()

		if initialized {
			next := (compress - int32(bitPos-bitMathMostSignificantBit(mask))) * tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized
	}

	wordPos, bitPos := tickBitmapPosition(compress + 1)

	_mask := new(u256.Uint).Lsh(u256.One(), uint(bitPos))
	_mask.Sub(_mask, u256.One())
	mask := bigintBitwiseNotForUint256BitmapIndexing(_mask)

	// XXXXXXXX overflow check Lsh!
	// requireUnsigned(mask, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__mask(%d) >= 0__#2", mask))

	masked := new(u256.Uint).And(pool.tickBitmaps[wordPos], mask)

	// XXXXXXXX overflow check And!
	//requireUnsigned(masked, ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapNextInitializedTickWithInOneWord__masked(%d) >= 0__#2", masked))

	initialized := !masked.IsZero()
	if initialized {
		next := (compress + 1 + int32(bitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
		return next, initialized
	} else {
		next := (compress + 1 + int32(int64(consts.MAX_UINT8-bigint(uint64(bitPos))))) * tickSpacing
		return next, initialized
	}
}

func bigintBitwiseNotForUint256BitmapIndexing(x *u256.Uint) *u256.Uint {
	// Create a mask with all bits set to 1
	mask := u256.FromBigint(consts.MAX_UINT256)
	mask.Sub(mask, u256.One())

	// XOR with mask to perform bitwise NOT
	result := new(u256.Uint).Xor(x, mask)
	return result
}
