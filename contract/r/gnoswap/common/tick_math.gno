package common

import (
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// TickMathGetSqrtRatioAtTick calculates the square root price ratio for a given tick.
//
// This function computes the square root ratio (sqrt(price)) at a specific tick,
// using precomputed ratios. The result is returned as a 160-bit fixed-point value (Q64.96 format).
//
// This implementation matches Uniswap V3's getSqrtRatioAtTick exactly.
//
// Parameters:
//   - tick (int32): The tick index for which the square root ratio is calculated.
//
// Returns:
//   - *u256.Uint: The square root price ratio at the given tick, represented as a 160-bit unsigned integer.
func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	assertValidTickRange(tick)
	absTick := abs(tick)

	// Initialize ratio based on LSB - exactly like Uniswap V3
	var ratio *u256.Uint
	
	if absTick&0x1 != 0 {
		ratio = u256.MustFromDecimal("340265354078544963557816517032075149313") // 0xfffcb933bd6fad37aa2d162d1a594001
	} else {
		ratio = u256.MustFromDecimal("340282366920938463463374607431768211456") // 0x100000000000000000000000000000000 (2^128)
	}

	// Apply bit masks exactly like Uniswap V3
	if absTick&0x2 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("340248342086729790484326174814286782778")), 128) // 0xfff97272373d413259a46990580e213a
	}

	if absTick&0x4 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("340214320654664324051920982716015181260")), 128) // 0xfff2e50f5f656932ef12357cf3c7fdcc
	}

	if absTick&0x8 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("340146287995602323631171512101879684304")), 128) // 0xffe5caca7e10e4e61c3624eaa0941cd0
	}

	if absTick&0x10 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("340010263488231146823593991679159461444")), 128) // 0xffcb9843d60f6159c9db58835c926644
	}

	if absTick&0x20 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("339738377640345403697157401104375502016")), 128) // 0xff973b41fa98c081472e6896dfb254c0
	}

	if absTick&0x40 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("339195258003219555707034227454543997025")), 128) // 0xff2ea16466c96a3843ec78b326b52861
	}

	if absTick&0x80 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("338111622100601834656805679988414885971")), 128) // 0xfe5dee046a99a2a811c461f1969c3053
	}

	if absTick&0x100 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("335954724994790223023589805789778977700")), 128) // 0xfcbe86c7900a88aedcffc83b479aa3a4
	}

	if absTick&0x200 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("331682121138379247127172139078559817300")), 128) // 0xf987a7253ac413176f2b074cf7815e54
	}

	if absTick&0x400 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("323299236684853023288211250268160618739")), 128) // 0xf3392b0822b70005940c7a398e4b70f3
	}

	if absTick&0x800 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("307163716377032989948697243942600083929")), 128) // 0xe7159475a2c29b7443b29c7fa6e889d9
	}

	if absTick&0x1000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("277268403626896220162999269216087595045")), 128) // 0xd097f3bdfd2022b8845ad8f792aa5825
	}

	if absTick&0x2000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("225923453940442621947126027127485391333")), 128) // 0xa9f746462d870fdf8a65dc1f90e061e5
	}

	if absTick&0x4000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("149997214084966997727330242082538205943")), 128) // 0x70d869a156d2a1b890bb3df62baf32f7
	}

	if absTick&0x8000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("66119101136024775622716233608466517926")), 128) // 0x31be135f97d08fd981231505542fcfa6
	}

	if absTick&0x10000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("12847376061809297530290974190478138313")), 128) // 0x9aa508b5b7a84e1c677de54f3e99bc9
	}

	if absTick&0x20000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("485053260817066172746253684029974020")), 128) // 0x5d6af8dedb81196699c329225ee604
	}

	if absTick&0x40000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("691415978906521570653435304214168")), 128) // 0x2216e584f5fa1ea926041bedfe98
	}

	if absTick&0x80000 != 0 {
		ratio = new(u256.Uint).Rsh(new(u256.Uint).Mul(ratio, u256.MustFromDecimal("1404880482679654955896180642")), 128) // 0x48a170391f7dc42444e8fa2
	}

	// Invert ratio for positive ticks
	if tick > 0 {
		maxUint256 := u256.MustFromDecimal(consts.MAX_UINT256)
		ratio = new(u256.Uint).Div(maxUint256, ratio)
	}

	// Convert from Q128.128 to Q128.96 with rounding up
	// This divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96
	oneLsh32 := new(u256.Uint).Lsh(u256.One(), 32) // 1 << 32

	upper := new(u256.Uint).Rsh(ratio, 32) // ratio >> 32
	remainder := new(u256.Uint).Mod(ratio, oneLsh32) // ratio % (1 << 32)

	// Round up: add 1 if remainder != 0
	if !remainder.IsZero() {
		upper = new(u256.Uint).Add(upper, u256.One())
	}

	return upper
}

// TickMathGetTickAtSqrtRatio calculates the greatest tick value such that getSqrtRatioAtTick(tick) <= ratio
//
// This implementation matches Uniswap V3's getTickAtSqrtRatio exactly.
//
// Parameters:
//   - sqrtPriceX96: The sqrt ratio for which to compute the tick as a Q64.96
//
// Returns:
//   - int32: The greatest tick for which the ratio is less than or equal to the input ratio
func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	// Validate input range
	minSqrtRatio := u256.MustFromDecimal(consts.MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(consts.MAX_SQRT_RATIO)
	
	if sqrtPriceX96.Lt(minSqrtRatio) || sqrtPriceX96.Gte(maxSqrtRatio) {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("sqrtPriceX96(%s) is out of range", sqrtPriceX96.ToString()),
		))
	}

	// Scale ratio by 32 bits to convert from Q64.96 to Q96.128
	ratio := new(u256.Uint).Lsh(sqrtPriceX96, 32)

	// Find MSB using binary search - matching Uniswap V3's assembly logic
	r := new(u256.Uint).Set(ratio)
	msb := u256.Zero()

	// Check if r > 2^128 - 1
	if r.Gt(u256.MustFromDecimal("340282366920938463463374607431768211455")) {
		f := u256.NewUint(128)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 128)
	}

	// Check if r > 2^64 - 1
	if r.Gt(u256.MustFromDecimal("18446744073709551615")) {
		f := u256.NewUint(64)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 64)
	}

	// Check if r > 2^32 - 1
	if r.Gt(u256.MustFromDecimal("4294967295")) {
		f := u256.NewUint(32)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 32)
	}

	// Check if r > 2^16 - 1
	if r.Gt(u256.NewUint(65535)) {
		f := u256.NewUint(16)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 16)
	}

	// Check if r > 2^8 - 1
	if r.Gt(u256.NewUint(255)) {
		f := u256.NewUint(8)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 8)
	}

	// Check if r > 2^4 - 1
	if r.Gt(u256.NewUint(15)) {
		f := u256.NewUint(4)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 4)
	}

	// Check if r > 2^2 - 1
	if r.Gt(u256.NewUint(3)) {
		f := u256.NewUint(2)
		msb = new(u256.Uint).Or(msb, f)
		r = new(u256.Uint).Rsh(r, 2)
	}

	// Check if r > 1
	if r.Gt(u256.One()) {
		f := u256.One()
		msb = new(u256.Uint).Or(msb, f)
	}

	// Adjust ratio based on MSB
	if msb.Gte(u256.NewUint(128)) {
		msbDiff := msb.Uint64() - 127
		r = new(u256.Uint).Rsh(ratio, uint(msbDiff))
	} else {
		msbDiff := 127 - msb.Uint64()
		r = new(u256.Uint).Lsh(ratio, uint(msbDiff))
	}

	// Calculate log_2 using fixed-point arithmetic
	msbInt := i256.FromUint256(msb)
	constant128 := i256.NewInt(128)
	log2 := new(i256.Int).Sub(msbInt, constant128)
	log2 = log2.Lsh(log2, 64)

	// Iterative calculation matching Uniswap V3's assembly blocks
	// bit 63
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f := new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 63))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 62
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 62))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 61
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 61))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 60
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 60))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 59
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 59))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 58
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 58))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 57
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 57))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 56
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 56))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 55
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 55))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 54
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 54))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 53
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 53))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 52
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 52))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 51
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 51))
	r = new(u256.Uint).Rsh(r, uint(f.Uint64()))

	// bit 50
	r = new(u256.Uint).Rsh(new(u256.Uint).Mul(r, r), 127)
	f = new(u256.Uint).Rsh(r, 128)
	log2 = i256.Zero().Or(log2, i256.Zero().Lsh(i256.FromUint256(f), 50))

	// Calculate tick from log_sqrt10001
	logSqrt10001 := new(i256.Int).Mul(log2, i256.MustFromDecimal("255738958999603826347141"))

	// Calculate tick bounds
	tickLow := new(i256.Int).Sub(logSqrt10001, i256.MustFromDecimal("3402992956809132418596140100660247210"))
	tickLow = tickLow.Rsh(tickLow, 128)
	tickLowInt32 := int32(tickLow.Int64())

	tickHi := new(i256.Int).Add(logSqrt10001, i256.MustFromDecimal("291339464771989622907027621153398088495"))
	tickHi = tickHi.Rsh(tickHi, 128)
	tickHiInt32 := int32(tickHi.Int64())

	// Select the appropriate tick
	if tickLowInt32 == tickHiInt32 {
		return tickLowInt32
	} else if TickMathGetSqrtRatioAtTick(tickHiInt32).Lte(sqrtPriceX96) {
		return tickHiInt32
	} else {
		return tickLowInt32
	}
}

// abs returns the absolute value of the given integer.
func abs(x int32) int32 {
	if x < 0 {
		return -x
	}
	return x
}

// assertValidTickRange validates that the absolute tick value is within the acceptable range.
func assertValidTickRange(tick int32) {
	if tick > consts.MAX_TICK {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("tick is out of range (larger than 887272), tick: %d", tick),
		))
	}
	if tick < consts.MIN_TICK {
		panic(newErrorWithDetail(
			errOutOfRange,
			ufmt.Sprintf("tick is out of range (smaller than -887272), tick: %d", tick),
		))
	}
}
