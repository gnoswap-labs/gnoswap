package position

import (
	pool "gno.land/r/pool"
)


func PoolTicksCounterCountInitializedTicksCrossed(
	tickBefore bigint,
	tickAfter bigint,
) (bigint) {
	var (
		wordPosLower bigint
		wordPosHigher bigint
		bitPosLower bigint
		bitPosHigher bigint
		tickBeforeInitialized bool
		tickAfterInitialized bool

		// return 
		initializedTicksCrossed bigint
	)

	{
		wordPos := (tickBefore / pool.GetPoolTickSpacing()) >> 8
		bitPos := (tickBefore / pool.GetPoolTickSpacing()) % 256

		wordPosAfter := (tickAfter / pool.GetPoolTickSpacing()) >> 8
		bitPosAfter := (tickAfter / pool.GetPoolTickSpacing()) % 256


		tickAfterInitialized =
			((pool.GetPoolTickBitmap(string(wordPosAfter)) & (1 << bitPosAfter)) > 0) &&
			((tickAfter % pool.GetPoolTickSpacing()) == 0) &&
			(tickBefore > tickAfter)

		tickBeforeInitialized =
			((pool.GetPoolTickBitmap(string(wordPos)) & (1 << bitPos)) > 0) &&
			((tickBefore % pool.GetPoolTickSpacing()) == 0) &&
			(tickBefore < tickAfter)

		if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
			wordPosLower = wordPos
			bitPosLower = bitPos
			wordPosHigher = wordPosAfter
			bitPosHigher = bitPosAfter
		} else {
			wordPosLower = wordPosAfter
			bitPosLower = bitPosAfter
			wordPosHigher = wordPos
			bitPosHigher = bitPos
		}
	}

	mask := MAX_UINT256 << bitPosLower

	for wordPosLower < wordPosHigher {
		if (wordPosLower == wordPosHigher) {
			mask = mask & (MAX_UINT256 >> (255 - bitPosHigher))
		}

		masked := pool.GetPoolTickBitmap(string(wordPosLower)) & mask
		initializedTicksCrossed += PoolTicksCounterCountOneBits(masked);
		wordPosLower++

		mask = MAX_UINT256
	}

	if (tickAfterInitialized) {
		initializedTicksCrossed--
	}

	if (tickBeforeInitialized) {
		initializedTicksCrossed--
	}

	return initializedTicksCrossed
}


func PoolTicksCounterCountOneBits(x bigint) (bigint) {
	bits := bigint(0)

	for x > 0 {
		bits++
		x &= x - 1
	}

	return bits
}