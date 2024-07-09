package common

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var tickRatioMap = map[int32]*u256.Uint{
	0x1:     u256.MustFromDecimal("340265354078544963557816517032075149313"), // 0xfffcb933bd6fad37aa2d162d1a594001,
	0x2:     u256.MustFromDecimal("340248342086729790484326174814286782778"), // 0xfff97272373d413259a46990580e213a,
	0x4:     u256.MustFromDecimal("340214320654664324051920982716015181260"), // 0xfff2e50f5f656932ef12357cf3c7fdcc,
	0x8:     u256.MustFromDecimal("340146287995602323631171512101879684304"), // 0xffe5caca7e10e4e61c3624eaa0941cd0,
	0x10:    u256.MustFromDecimal("340010263488231146823593991679159461444"), // 0xffcb9843d60f6159c9db58835c926644,
	0x20:    u256.MustFromDecimal("339738377640345403697157401104375502016"), // 0xff973b41fa98c081472e6896dfb254c0,
	0x40:    u256.MustFromDecimal("339195258003219555707034227454543997025"), // 0xff2ea16466c96a3843ec78b326b52861,
	0x80:    u256.MustFromDecimal("338111622100601834656805679988414885971"), // 0xfe5dee046a99a2a811c461f1969c3053,
	0x100:   u256.MustFromDecimal("335954724994790223023589805789778977700"), // 0xfcbe86c7900a88aedcffc83b479aa3a4,
	0x200:   u256.MustFromDecimal("331682121138379247127172139078559817300"), // 0xf987a7253ac413176f2b074cf7815e54,
	0x400:   u256.MustFromDecimal("323299236684853023288211250268160618739"), // 0xf3392b0822b70005940c7a398e4b70f3,
	0x800:   u256.MustFromDecimal("307163716377032989948697243942600083929"), // 0xe7159475a2c29b7443b29c7fa6e889d9,
	0x1000:  u256.MustFromDecimal("277268403626896220162999269216087595045"), // 0xd097f3bdfd2022b8845ad8f792aa5825,
	0x2000:  u256.MustFromDecimal("225923453940442621947126027127485391333"), // 0xa9f746462d870fdf8a65dc1f90e061e5,
	0x4000:  u256.MustFromDecimal("149997214084966997727330242082538205943"), // 0x70d869a156d2a1b890bb3df62baf32f7,
	0x8000:  u256.MustFromDecimal("66119101136024775622716233608466517926"),  // 0x31be135f97d08fd981231505542fcfa6,
	0x10000: u256.MustFromDecimal("12847376061809297530290974190478138313"),  // 0x9aa508b5b7a84e1c677de54f3e99bc9,
	0x20000: u256.MustFromDecimal("485053260817066172746253684029974020"),    // 0x5d6af8dedb81196699c329225ee604,
	0x40000: u256.MustFromDecimal("691415978906521570653435304214168"),       // 0x2216e584f5fa1ea926041bedfe98,
	0x80000: u256.MustFromDecimal("1404880482679654955896180642"),            // 0x48a170391f7dc42444e8fa2,
}

var binaryLogConsts = [8]*u256.Uint{
	u256.MustFromDecimal("0"),                                       // 0x0,
	u256.MustFromDecimal("3"),                                       // 0x3,
	u256.MustFromDecimal("15"),                                      // 0xF,
	u256.MustFromDecimal("255"),                                     // 0xFF,
	u256.MustFromDecimal("65535"),                                   // 0xFFFF,
	u256.MustFromDecimal("4294967295"),                              // 0xFFFFFFFF,
	u256.MustFromDecimal("18446744073709551615"),                    // 0xFFFFFFFFFFFFFFFF,
	u256.MustFromDecimal("340282366920938463463374607431768211455"), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
}

var (
	shift1By32Left = u256.MustFromDecimal("4294967296") // (1 << 32)
)

func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint { // uint160 sqrtPriceX96
	absTick := abs(tick)
	ratio := u256.MustFromDecimal("340282366920938463463374607431768211456") // consts.Q128

	for mask, value := range tickRatioMap {
		if absTick&mask != 0 {
			// ratio = (ratio * value) >> 128
			ratio = ratio.Mul(ratio, value)
			ratio = ratio.Rsh(ratio, 128)
		}
	}

	if tick > 0 {
		_maxUint256 := u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935") // consts.MAX_UINT256
		_tmp := new(u256.Uint).Div(_maxUint256, ratio)
		ratio = _tmp.Clone()
	}

	shifted := ratio.Rsh(ratio, 32).Clone()

	remainder := ratio.Mod(ratio, shift1By32Left)

	if new(u256.Uint).Add(shifted.Clone(), remainder.Clone()).IsZero() {
		return shifted
	}

	return new(u256.Uint).Add(shifted, u256.One())
}

func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {

	ratio := new(u256.Uint).Lsh(sqrtPriceX96, 32)

	msb, adjustedRatio := findMSB(ratio)
	adjustedRatio = adjustRatio(ratio, msb)

	log2 := calculateLog2(msb, adjustedRatio)
	tick := getTickValue(log2, sqrtPriceX96)

	return tick
}

// findMSB computes the MSB (most significant bit) of the given ratio.
func findMSB(ratio *u256.Uint) (*u256.Uint, *u256.Uint) {
	msb := u256.Zero()

	for i := 7; i >= 1; i-- {
		f := new(u256.Uint).Lsh(gt(ratio, binaryLogConsts[i]), uint(i))
		msb = new(u256.Uint).Or(msb, f)
		ratio = new(u256.Uint).Rsh(ratio, uint(f.Uint64()))
	}

	// handle the remaining bits
	{
		f := gt(ratio, u256.One()) // 0x1
		// msb = msb | f
		msb = new(u256.Uint).Or(msb, f)
	}

	return msb, ratio
}

// adjustRatio adjusts the given ratio based on the MSB found.
//
// This adjustment ensures that the ratio falls within the specific range.
func adjustRatio(ratio, msb *u256.Uint) *u256.Uint {
	if msb.Gte(u256.NewUint(128)) {
		return new(u256.Uint).Rsh(ratio, uint(msb.Uint64()-127))
	}

	return new(u256.Uint).Lsh(ratio, uint(127-msb.Uint64()))
}

// calculateLog2 calculates the binary logarith, of the adjusted ratio using a fixed-point arithmetic.
//
// This function iteratively squares the ratio and adjusts the result to compute the log base 2, which will determine the tick value.
func calculateLog2(msb, ratio *u256.Uint) *i256.Int {
	_msb := i256.FromUint256(msb)
	_128 := i256.NewInt(128)

	log_2 := i256.Zero().Sub(_msb, _128)
	log_2 = log_2.Lsh(log_2, 64)

	for i := 63; i >= 51; i-- {
		ratio = new(u256.Uint).Mul(ratio, ratio)
		ratio = ratio.Rsh(ratio, 127)

		f := i256.FromUint256(new(u256.Uint).Rsh(ratio, 128))

		// log_2 = log_2 | (f << i)
		log_2 = i256.Zero().Or(log_2, i256.Zero().Lsh(f, uint(i)))

		// ratio = ratio >> uint64(f)
		ratio = ratio.Rsh(ratio, uint(f.Uint64()))
	}

	// handle the remaining bits
	{
		// ratio = ratio * ratio >> 127
		ratio = new(u256.Uint).Mul(ratio, ratio)
		ratio = new(u256.Uint).Rsh(ratio, 127)

		f := i256.FromUint256(new(u256.Uint).Rsh(ratio, 128))

		log_2 = i256.Zero().Or(log_2, i256.Zero().Lsh(f, 50))
	}

	return log_2
}

// getTickValue determines the tick value corresponding to a given sqrtPriveX96.
//
// It calculates the upper and lower bounds for each tick, and selects the appropriate tock value
// based on the given sqrtPriceX96.
func getTickValue(log2 *i256.Int, sqrtPriceX96 *u256.Uint) int32 {
	// ref: https://github.com/Uniswap/v3-core/issues/500
	// 2^64 / log2 (√1.0001) = 255738958999603826347141
	log_sqrt10001 := i256.Zero().Mul(log2, i256.MustFromDecimal("255738958999603826347141"))

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.010000497 x 2^128 = 3402992956809132418596140100660247210
	tickLow256 := i256.Zero().Sub(log_sqrt10001, i256.MustFromDecimal("3402992956809132418596140100660247210"))
	tickLow256 = tickLow256.Rsh(tickLow256, 128)
	tickLow := int32(tickLow256.Int64())

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.856 x 2^128 = 291339464771989622907027621153398088495
	tickHi256 := i256.Zero().Add(log_sqrt10001, i256.MustFromDecimal("291339464771989622907027621153398088495"))
	tickHi256 = tickHi256.Rsh(tickHi256, 128)
	tickHi := int32(tickHi256.Int64())

	var tick int32
	if tickLow == tickHi {
		tick = tickLow
	} else if TickMathGetSqrtRatioAtTick(tickHi).Lte(sqrtPriceX96) {
		tick = tickHi
	} else {
		tick = tickLow
	}

	return tick
}

func gt(x, y *u256.Uint) *u256.Uint {
	if x.Gt(y) {
		return u256.One()
	}

	return u256.Zero()
}

func abs(x int32) int32 {
	if x < 0 {
		return -x
	}

	return x
}
