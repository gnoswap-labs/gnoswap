package position

// XXX
// import (
// 	p "gno.land/r/pool"
// )

// func PoolTicksCounterCountInitializedTicksCrossed(
// 	tickBefore bigint,
// 	tickAfter bigint,
// ) bigint {
// 	var (
// 		wordPosLower          bigint
// 		wordPosHigher         bigint
// 		bitPosLower           bigint
// 		bitPosHigher          bigint
// 		tickBeforeInitialized bool
// 		tickAfterInitialized  bool

// 		// return
// 		initializedTicksCrossed bigint
// 	)

// 	{
// 		wordPos := (tickBefore / p.GetPoolTickSpacing()) >> 8
// 		bitPos := (tickBefore / p.GetPoolTickSpacing()) % 256

// 		wordPosAfter := (tickAfter / p.GetPoolTickSpacing()) >> 8
// 		bitPosAfter := (tickAfter / p.GetPoolTickSpacing()) % 256

// 		tickAfterInitialized =
// 			((p.GetPoolTickBitmap(string(wordPosAfter)) & (1 << bitPosAfter)) > 0) &&
// 				((tickAfter % p.GetPoolTickSpacing()) == 0) &&
// 				(tickBefore > tickAfter)

// 		tickBeforeInitialized =
// 			((p.GetPoolTickBitmap(string(wordPos)) & (1 << bitPos)) > 0) &&
// 				((tickBefore % p.GetPoolTickSpacing()) == 0) &&
// 				(tickBefore < tickAfter)

// 		if wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter) {
// 			wordPosLower = wordPos
// 			bitPosLower = bitPos
// 			wordPosHigher = wordPosAfter
// 			bitPosHigher = bitPosAfter
// 		} else {
// 			wordPosLower = wordPosAfter
// 			bitPosLower = bitPosAfter
// 			wordPosHigher = wordPos
// 			bitPosHigher = bitPos
// 		}
// 	}

// 	mask := MAX_UINT256 << bitPosLower

// 	for wordPosLower < wordPosHigher {
// 		if wordPosLower == wordPosHigher {
// 			mask = mask & (MAX_UINT256 >> (255 - bitPosHigher))
// 		}

// 		masked := p.GetPoolTickBitmap(string(wordPosLower)) & mask
// 		initializedTicksCrossed += PoolTicksCounterCountOneBits(masked)
// 		wordPosLower++

// 		mask = MAX_UINT256
// 	}

// 	if tickAfterInitialized {
// 		initializedTicksCrossed--
// 	}

// 	if tickBeforeInitialized {
// 		initializedTicksCrossed--
// 	}

// 	return initializedTicksCrossed
// }

// func PoolTicksCounterCountOneBits(x bigint) bigint {
// 	bits := bigint(0)

// 	for x > 0 {
// 		bits++
// 		x &= x - 1
// 	}

// 	return bits
// }
