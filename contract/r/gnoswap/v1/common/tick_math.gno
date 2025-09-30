package common

import (
	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Pre-calculated ratio constants for performance optimization.
// These values are pre-computed to avoid runtime decimal parsing.
var (
	// Initial ratio constants - exactly matching Uniswap V3
	ratio0 = u256.MustFromDecimal("340265354078544963557816517032075149313") // 0xfffcb933bd6fad37aa2d162d1a594001
	ratio1 = u256.MustFromDecimal("340282366920938463463374607431768211456") // 0x100000000000000000000000000000000 (2^128)

	// Bit mask ratio constants in order (bit 1 to bit 19)
	ratioConstants = []*u256.Uint{
		u256.MustFromDecimal("340248342086729790484326174814286782778"), // 0xfff97272373d413259a46990580e213a (bit 1)
		u256.MustFromDecimal("340214320654664324051920982716015181260"), // 0xfff2e50f5f656932ef12357cf3c7fdcc (bit 2)
		u256.MustFromDecimal("340146287995602323631171512101879684304"), // 0xffe5caca7e10e4e61c3624eaa0941cd0 (bit 3)
		u256.MustFromDecimal("340010263488231146823593991679159461444"), // 0xffcb9843d60f6159c9db58835c926644 (bit 4)
		u256.MustFromDecimal("339738377640345403697157401104375502016"), // 0xff973b41fa98c081472e6896dfb254c0 (bit 5)
		u256.MustFromDecimal("339195258003219555707034227454543997025"), // 0xff2ea16466c96a3843ec78b326b52861 (bit 6)
		u256.MustFromDecimal("338111622100601834656805679988414885971"), // 0xfe5dee046a99a2a811c461f1969c3053 (bit 7)
		u256.MustFromDecimal("335954724994790223023589805789778977700"), // 0xfcbe86c7900a88aedcffc83b479aa3a4 (bit 8)
		u256.MustFromDecimal("331682121138379247127172139078559817300"), // 0xf987a7253ac413176f2b074cf7815e54 (bit 9)
		u256.MustFromDecimal("323299236684853023288211250268160618739"), // 0xf3392b0822b70005940c7a398e4b70f3 (bit 10)
		u256.MustFromDecimal("307163716377032989948697243942600083929"), // 0xe7159475a2c29b7443b29c7fa6e889d9 (bit 11)
		u256.MustFromDecimal("277268403626896220162999269216087595045"), // 0xd097f3bdfd2022b8845ad8f792aa5825 (bit 12)
		u256.MustFromDecimal("225923453940442621947126027127485391333"), // 0xa9f746462d870fdf8a65dc1f90e061e5 (bit 13)
		u256.MustFromDecimal("149997214084966997727330242082538205943"), // 0x70d869a156d2a1b890bb3df62baf32f7 (bit 14)
		u256.MustFromDecimal("66119101136024775622716233608466517926"),  // 0x31be135f97d08fd981231505542fcfa6 (bit 15)
		u256.MustFromDecimal("12847376061809297530290974190478138313"),  // 0x9aa508b5b7a84e1c677de54f3e99bc9 (bit 16)
		u256.MustFromDecimal("485053260817066172746253684029974020"),    // 0x5d6af8dedb81196699c329225ee604 (bit 17)
		u256.MustFromDecimal("691415978906521570653435304214168"),       // 0x2216e584f5fa1ea926041bedfe98 (bit 18)
		u256.MustFromDecimal("1404880482679654955896180642"),            // 0x48a170391f7dc42444e8fa2 (bit 19)
	}

	// Pre-computed constants for optimization
	maxUint256   = u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935") // 2^256 - 1
	minSqrtRatio = u256.MustFromDecimal("4295128739")                                                                     // same as TickMathGetSqrtRatioAtTick(minTick)
	maxSqrtRatio = u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")                              // same as TickMathGetSqrtRatioAtTick(maxTick)

	// MSB calculation thresholds - pre-computed for performance
	msb128Threshold = u256.MustFromDecimal("340282366920938463463374607431768211455") // 2^128 - 1
	msb64Threshold  = u256.MustFromDecimal("18446744073709551615")                    // 2^64 - 1
	msb32Threshold  = u256.MustFromDecimal("4294967295")                              // 2^32 - 1
	msb16Threshold  = u256.NewUint(65535)                                             // 2^16 - 1
	msb8Threshold   = u256.NewUint(255)                                               // 2^8 - 1
	msb4Threshold   = u256.NewUint(15)                                                // 2^4 - 1
	msb2Threshold   = u256.NewUint(3)                                                 // 2^2 - 1
	msb1Threshold   = u256.One()                                                      // 1

	// Pre-computed constants for tick calculation
	log2Multiplier = i256.MustFromDecimal("255738958999603826347141")
	tickLowOffset  = i256.MustFromDecimal("3402992956809132418596140100660247210")
	tickHiOffset   = i256.MustFromDecimal("291339464771989622907027621153398088495")

	oneLsh32 = u256.One().Lsh(u256.One(), 32) // 1 << 32
)

// TickMathGetSqrtRatioAtTick calculates sqrt price ratio for given tick.
//
// Converts tick index to square root price in Q64.96 fixed-point format.
// Based on Uniswap V3's mathematical formula: price = 1.0001^tick.
// Uses bit manipulation for gas-efficient calculation.
//
// Parameters:
//   - tick: Tick index in range [-887272, 887272]
//
// Returns:
//   - Square root of price ratio as Q64.96 fixed-point
//   - Result represents sqrt(token1/token0) price
//
// Mathematical formula:
//
//	sqrtPriceX96 = sqrt(1.0001^tick) * 2^96
//
// Panics if tick outside valid range.
// Critical for all price calculations in concentrated liquidity.
func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	assertValidTickRange(tick)
	absTick := abs(tick)

	// Initialize ratio based on LSB - exactly like Uniswap V3
	var ratio *u256.Uint

	if absTick&0x1 != 0 {
		ratio = ratio0.Clone()
	} else {
		ratio = ratio1.Clone()
	}

	temp := u256.Zero()

	// Apply bit masks using optimized loop - maintains exact same logic
	for i := 1; i < 20; i++ {
		if absTick&(1<<uint(i)) != 0 {
			// Use temporary variables to avoid memory allocation in hot path
			temp = temp.Mul(ratio, ratioConstants[i-1])
			ratio = ratio.Rsh(temp, 128)
		}
	}

	// Invert ratio for positive ticks
	if tick > 0 {
		ratio = temp.Div(maxUint256, ratio)
	}

	// Convert from Q128.128 to Q128.96 with rounding up.
	// This divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96
	upper := u256.Zero().Rsh(ratio, 32)           // ratio >> 32
	remainder := u256.Zero().Mod(ratio, oneLsh32) // ratio % (1 << 32)

	// Round up: add 1 if remainder != 0
	if !remainder.IsZero() {
		upper = u256.Zero().Add(upper, u256.One())
	}

	return upper
}

// getMostSignificantBit returns the position of the most significant bit.
func getMostSignificantBit(r *u256.Uint) (msb uint64) {
	temp := r.Clone()

	// Optimized MSB calculation using pre-computed thresholds
	if temp.Gt(msb128Threshold) {
		msb |= 128
		temp = temp.Rsh(temp, 128)
	}

	if temp.Gt(msb64Threshold) {
		msb |= 64
		temp = temp.Rsh(temp, 64)
	}

	if temp.Gt(msb32Threshold) {
		msb |= 32
		temp = temp.Rsh(temp, 32)
	}

	if temp.Gt(msb16Threshold) {
		msb |= 16
		temp = temp.Rsh(temp, 16)
	}

	if temp.Gt(msb8Threshold) {
		msb |= 8
		temp = temp.Rsh(temp, 8)
	}

	if temp.Gt(msb4Threshold) {
		msb |= 4
		temp = temp.Rsh(temp, 4)
	}

	if temp.Gt(msb2Threshold) {
		msb |= 2
		temp = temp.Rsh(temp, 2)
	}

	if temp.Gt(msb1Threshold) {
		msb |= 1
	}

	return
}

// TickMathGetTickAtSqrtRatio calculates tick value for given sqrt price ratio, returning greatest tick where getSqrtRatioAtTick(tick) <= ratio, matching Uniswap V3 exactly.
func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	if sqrtPriceX96.Lt(minSqrtRatio) || sqrtPriceX96.Gte(maxSqrtRatio) {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("sqrtPriceX96(%s) is out of range", sqrtPriceX96.ToString()),
		))
	}

	// Scale ratio by 32 bits to convert from Q64.96 to Q96.128
	ratio := u256.Zero().Lsh(sqrtPriceX96, 32)

	// Find MSB using optimized calculation
	msb := getMostSignificantBit(ratio)

	// Adjust ratio based on MSB
	var r *u256.Uint

	if msb >= 128 {
		r = u256.Zero().Rsh(ratio, uint(msb-127))
	} else {
		r = u256.Zero().Lsh(ratio, uint(127-msb))
	}

	// Calculate log_2 using fixed-point arithmetic
	log2 := i256.NewInt(int64(msb) - 128)
	log2 = i256.Zero().Lsh(log2, 64)

	// Define temporary variables for optimization
	tempR := u256.Zero()
	tempF := u256.Zero()
	tempI256 := i256.Zero()

	// Optimized iterative calculation using loop - maintains exact same logic
	for i := 0; i < 14; i++ {
		tempR = tempR.Mul(r, r)
		r = u256.Zero().Rsh(tempR, 127)

		tempF = tempF.Rsh(r, 128)
		tempI256 = i256.FromUint256(tempF)
		f := tempF

		tempI256 = tempI256.Lsh(tempI256, uint(63-i))
		log2 = log2.Or(log2, tempI256)
		r = u256.Zero().Rsh(r, uint(f.Uint64()))
	}

	// Calculate tick from log_sqrt10001
	logSqrt10001 := i256.Zero().Mul(log2, log2Multiplier)

	// Calculate tick bounds
	tickLow := i256.Zero().Sub(logSqrt10001, tickLowOffset)
	tickLow = tickLow.Rsh(tickLow, 128)
	tickLowInt32 := int32(tickLow.Int64())

	tickHi := i256.Zero().Add(logSqrt10001, tickHiOffset)
	tickHi = tickHi.Rsh(tickHi, 128)
	tickHiInt32 := int32(tickHi.Int64())

	// Select the appropriate tick
	if tickLowInt32 == tickHiInt32 {
		return tickLowInt32
	} else if TickMathGetSqrtRatioAtTick(tickHiInt32).Lte(sqrtPriceX96) {
		return tickHiInt32
	}

	return tickLowInt32
}

// abs returns the absolute value of x.
func abs(x int32) int32 {
	if x < 0 {
		return -x
	}

	return x
}

// assertValidTickRange panics if tick is outside valid range [-887272, 887272].
func assertValidTickRange(tick int32) {
	if tick > maxTick {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("tick is out of range (larger than 887272), tick: %d", tick),
		))
	}
	if tick < minTick {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("tick is out of range (smaller than -887272), tick: %d", tick),
		))
	}
}
