package gnsmath

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/consts"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Pre-calculated ratio constants for performance optimization.
//
// These were previously package-level vars (a slice plus 19 exposed pointers),
// the exact "globally exposed mutable array" anti-pattern. They are now
// constructors: each call returns freshly allocated values built from
// little-endian [4]uint64 literals, so no caller shares a mutable instance and
// no runtime decimal parsing happens. Values match Uniswap V3 exactly.

// initialRatio returns the LSB-selected initial ratio.
// absTick&0x1 != 0 selects ratio0 (0xfffcb933bd6fad37aa2d162d1a594001),
// otherwise ratio1 (2^128).
func initialRatio(odd bool) *u256.Uint {
	if odd {
		return &u256.Uint{12262481743371124737, 18445821805675392311, 0, 0} // 0xfffcb933bd6fad37aa2d162d1a594001
	}
	return &u256.Uint{0, 0, 1, 0} // 0x100000000000000000000000000000000 (2^128)
}

// ratioConstants returns the bit-mask ratio constants in order (bit 1 to bit 19).
func ratioConstants() []*u256.Uint {
	return []*u256.Uint{
		&u256.Uint{6459403834229662010, 18444899583751176498, 0, 0},  // 0xfff97272373d413259a46990580e213a (bit 1)
		&u256.Uint{17226890335427755468, 18443055278223354162, 0, 0}, // 0xfff2e50f5f656932ef12357cf3c7fdcc (bit 2)
		&u256.Uint{2032852871939366096, 18439367220385604838, 0, 0},  // 0xffe5caca7e10e4e61c3624eaa0941cd0 (bit 3)
		&u256.Uint{14545316742740207172, 18431993317065449817, 0, 0}, // 0xffcb9843d60f6159c9db58835c926644 (bit 4)
		&u256.Uint{5129152022828963008, 18417254355718160513, 0, 0},  // 0xff973b41fa98c081472e6896dfb254c0 (bit 5)
		&u256.Uint{4894419605888772193, 18387811781193591352, 0, 0},  // 0xff2ea16466c96a3843ec78b326b52861 (bit 6)
		&u256.Uint{1280255884321894483, 18329067761203520168, 0, 0},  // 0xfe5dee046a99a2a811c461f1969c3053 (bit 7)
		&u256.Uint{15924666964335305636, 18212142134806087854, 0, 0}, // 0xfcbe86c7900a88aedcffc83b479aa3a4 (bit 8)
		&u256.Uint{8010504389359918676, 17980523815641551639, 0, 0},  // 0xf987a7253ac413176f2b074cf7815e54 (bit 9)
		&u256.Uint{10668036004952895731, 17526086738831147013, 0, 0}, // 0xf3392b0822b70005940c7a398e4b70f3 (bit 10)
		&u256.Uint{4878133418470705625, 16651378430235024244, 0, 0},  // 0xe7159475a2c29b7443b29c7fa6e889d9 (bit 11)
		&u256.Uint{9537173718739605541, 15030750278693429944, 0, 0},  // 0xd097f3bdfd2022b8845ad8f792aa5825 (bit 12)
		&u256.Uint{9972618978014552549, 12247334978882834399, 0, 0},  // 0xa9f746462d870fdf8a65dc1f90e061e5 (bit 13)
		&u256.Uint{10428997489610666743, 8131365268884726200, 0, 0},  // 0x70d869a156d2a1b890bb3df62baf32f7 (bit 14)
		&u256.Uint{9305304367709015974, 3584323654723342297, 0, 0},   // 0x31be135f97d08fd981231505542fcfa6 (bit 15)
		&u256.Uint{14301143598189091785, 696457651847595233, 0, 0},   // 0x9aa508b5b7a84e1c677de54f3e99bc9 (bit 16)
		&u256.Uint{7393154844743099908, 26294789957452057, 0, 0},     // 0x5d6af8dedb81196699c329225ee604 (bit 17)
		&u256.Uint{2209338891292245656, 37481735321082, 0, 0},        // 0x2216e584f5fa1ea926041bedfe98 (bit 18)
		&u256.Uint{10518117631919034274, 76158723, 0, 0},             // 0x48a170391f7dc42444e8fa2 (bit 19)
	}
}

// MSB calculation thresholds - returned as fresh instances per call.
func msb128Threshold() *u256.Uint {
	return &u256.Uint{18446744073709551615, 18446744073709551615, 0, 0}
}                                // 2^128 - 1
func msb64Threshold() *u256.Uint { return &u256.Uint{18446744073709551615, 0, 0, 0} } // 2^64 - 1
func msb32Threshold() *u256.Uint { return &u256.Uint{4294967295, 0, 0, 0} }           // 2^32 - 1
func msb16Threshold() *u256.Uint { return &u256.Uint{65535, 0, 0, 0} }                // 2^16 - 1
func msb8Threshold() *u256.Uint  { return &u256.Uint{255, 0, 0, 0} }                  // 2^8 - 1
func msb4Threshold() *u256.Uint  { return &u256.Uint{15, 0, 0, 0} }                   // 2^4 - 1
func msb2Threshold() *u256.Uint  { return &u256.Uint{3, 0, 0, 0} }                    // 2^2 - 1
func msb1Threshold() *u256.Uint  { return &u256.Uint{1, 0, 0, 0} }                    // 1

// Pre-computed constants for tick calculation - returned as fresh instances per call.
func log2Multiplier() *i256.Int { return &i256.Int{11745905768312294533, 13863, 0, 0} }               // 255738958999603826347141
func tickLowOffset() *i256.Int  { return &i256.Int{6552757943157144234, 184476617836266586, 0, 0} }   // 3402992956809132418596140100660247210
func tickHiOffset() *i256.Int   { return &i256.Int{4998474450511881007, 15793544031827761793, 0, 0} } // 291339464771989622907027621153398088495

// oneLsh32 returns 1 << 32.
func oneLsh32() *u256.Uint { return &u256.Uint{4294967296, 0, 0, 0} }

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
	ratio := initialRatio(absTick&0x1 != 0)

	temp := u256.Zero()
	masks := ratioConstants()

	// Apply bit masks using optimized loop - maintains exact same logic
	for i := 1; i < 20; i++ {
		if absTick&(1<<uint(i)) != 0 {
			// Use temporary variables to avoid memory allocation in hot path
			r := masks[i-1]
			temp, overflow := temp.MulOverflow(ratio, r)
			if overflow {
				panic(errTickMathOverflow)
			}
			ratio = ratio.Rsh(temp, 128)
		}
	}

	// Invert ratio for positive ticks
	if tick > 0 {
		ratio = temp.Div(consts.MaxUint256(), ratio)
	}

	// Convert from Q128.128 to Q128.96 with rounding up.
	// This divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96
	upper := u256.Zero().Rsh(ratio, 32)             // ratio >> 32
	remainder := u256.Zero().Mod(ratio, oneLsh32()) // ratio % (1 << 32)

	// Round up: add 1 if remainder != 0
	if !remainder.IsZero() {
		upper = u256.Zero().Add(upper, u256.One())
	}

	return upper
}

// getMostSignificantBit returns the position of the most significant bit (MSB) in a uint256 value.
// Uses binary search with pre-computed thresholds for efficient calculation.
//
// Parameters:
//   - r: uint256 value to find MSB for
//
// Returns:
//   - msb: position of the most significant bit (0-255)
//
// Used internally for logarithm calculations in tick math.
func getMostSignificantBit(r *u256.Uint) (msb uint64) {
	temp := r.Clone()

	// Optimized MSB calculation using pre-computed thresholds
	if temp.Gt(msb128Threshold()) {
		msb |= 128
		temp = temp.Rsh(temp, 128)
	}

	if temp.Gt(msb64Threshold()) {
		msb |= 64
		temp = temp.Rsh(temp, 64)
	}

	if temp.Gt(msb32Threshold()) {
		msb |= 32
		temp = temp.Rsh(temp, 32)
	}

	if temp.Gt(msb16Threshold()) {
		msb |= 16
		temp = temp.Rsh(temp, 16)
	}

	if temp.Gt(msb8Threshold()) {
		msb |= 8
		temp = temp.Rsh(temp, 8)
	}

	if temp.Gt(msb4Threshold()) {
		msb |= 4
		temp = temp.Rsh(temp, 4)
	}

	if temp.Gt(msb2Threshold()) {
		msb |= 2
		temp = temp.Rsh(temp, 2)
	}

	if temp.Gt(msb1Threshold()) {
		msb |= 1
	}

	return
}

// TickMathGetTickAtSqrtRatio calculates the tick index for a given square root price ratio.
//
// Converts a square root price ratio in Q64.96 format back to its tick index,
// returning the greatest tick where TickMathGetSqrtRatioAtTick(tick) <= sqrtPriceX96.
// This matches Uniswap V3's behavior exactly.
//
// Parameters:
//   - sqrtPriceX96: Square root price ratio in Q64.96 format
//
// Returns:
//   - Tick index corresponding to the price
//
// Algorithm:
//  1. Scales ratio from Q64.96 to Q96.128 by left-shifting 32 bits
//  2. Finds MSB (most significant bit) to determine magnitude
//  3. Calculates log_2 using fixed-point arithmetic
//  4. Converts log_2 to log_sqrt(1.0001) to get tick
//  5. Returns appropriate tick based on bounds checking
//
// Panics if sqrtPriceX96 is nil or outside valid range [minSqrtRatio, maxSqrtRatio).
// Critical for converting prices to ticks for position management.
func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	if sqrtPriceX96 == nil {
		panic(newErrorWithDetail(
			errTickMathInvalidInput,
			"sqrtPriceX96 cannot be nil",
		))
	}

	if sqrtPriceX96.Lt(consts.MinSqrtRatio()) || sqrtPriceX96.Gte(consts.MaxSqrtRatio()) {
		panic(newErrorWithDetail(
			errTickMathOutOfRange,
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
		tempR, overflow := tempR.MulOverflow(r, r)
		if overflow {
			panic(errTickMathOverflow)
		}
		r = tempR.Rsh(tempR, 127)

		tempF = tempF.Rsh(r, 128)
		tempI256 = i256.FromUint256(tempF)
		f := tempF

		tempI256 = tempI256.Lsh(tempI256, uint(63-i))
		log2 = log2.Or(log2, tempI256)
		r = r.Rsh(r, uint(f.Uint64()))
	}

	// Calculate tick from log_sqrt10001
	logSqrt10001, overflow := i256.Zero().MulOverflow(log2, log2Multiplier())
	if overflow {
		panic(errTickMathOverflow)
	}

	// Calculate tick bounds
	tickLow := i256.Zero().Sub(logSqrt10001, tickLowOffset())
	tickLow = tickLow.Rsh(tickLow, 128)
	tickLowInt32 := int32(tickLow.Int64())

	tickHi := i256.Zero().Add(logSqrt10001, tickHiOffset())
	tickHi = tickHi.Rsh(tickHi, 128)
	tickHiInt32 := int32(tickHi.Int64())

	// Select the appropriate tick
	if tickLowInt32 == tickHiInt32 {
		return tickLowInt32
	}

	if TickMathGetSqrtRatioAtTick(tickHiInt32).Lte(sqrtPriceX96) {
		return tickHiInt32
	}

	return tickLowInt32
}

// abs returns the absolute value of a signed 32-bit integer.
// Used internally for tick math calculations to handle negative tick indices.
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
			errTickMathOutOfRange,
			ufmt.Sprintf("tick is out of range (larger than 887272), tick: %d", tick),
		))
	}
	if tick < minTick {
		panic(newErrorWithDetail(
			errTickMathOutOfRange,
			ufmt.Sprintf("tick is out of range (smaller than -887272), tick: %d", tick),
		))
	}
}
