package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

var tickRatioMap = map[bigint]bigint{
	0x1:     0xfffcb933bd6fad37aa2d162d1a594001,
	0x2:     0xfff97272373d413259a46990580e213a,
	0x4:     0xfff2e50f5f656932ef12357cf3c7fdcc,
	0x8:     0xffe5caca7e10e4e61c3624eaa0941cd0,
	0x10:    0xffcb9843d60f6159c9db58835c926644,
	0x20:    0xff973b41fa98c081472e6896dfb254c0,
	0x40:    0xff2ea16466c96a3843ec78b326b52861,
	0x80:    0xfe5dee046a99a2a811c461f1969c3053,
	0x100:   0xfcbe86c7900a88aedcffc83b479aa3a4,
	0x200:   0xf987a7253ac413176f2b074cf7815e54,
	0x400:   0xf3392b0822b70005940c7a398e4b70f3,
	0x800:   0xe7159475a2c29b7443b29c7fa6e889d9,
	0x1000:  0xd097f3bdfd2022b8845ad8f792aa5825,
	0x2000:  0xa9f746462d870fdf8a65dc1f90e061e5,
	0x4000:  0x70d869a156d2a1b890bb3df62baf32f7,
	0x8000:  0x31be135f97d08fd981231505542fcfa6,
	0x10000: 0x9aa508b5b7a84e1c677de54f3e99bc9,
	0x20000: 0x5d6af8dedb81196699c329225ee604,
	0x40000: 0x2216e584f5fa1ea926041bedfe98,
	0x80000: 0x48a170391f7dc42444e8fa2,
}

var binaryLogConsts = [8]bigint{
	0x0,
	0x3,
	0xF,
	0xFF,
	0xFFFF,
	0xFFFFFFFF,
	0xFFFFFFFFFFFFFFFF,
	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
}

func TickMathGetSqrtRatioAtTick(tick int32) bigint {
	absTick := absTick(tick)
	require(
		absTick <= bigint(consts.MAX_TICK),
		ufmt.Sprintf(
			"[POOL] tick_math.gno__TickMathGetSqrtRatioAtTick() || absTick(%d) <= consts.MAX_TICK(%d)",
			absTick, consts.MAX_TICK,
		),
	)

	ratio := consts.Q128
	for mask, value := range tickRatioMap {
		if absTick&mask != 0 {
			ratio = (ratio * value) >> 128
		}
	}

	if tick > 0 {
		ratio = consts.MAX_UINT256 / ratio
	}

	shifted := ratio >> 32
	remainder := ratio % (1 << 32)

	if shifted+remainder == 0 {
		return shifted + 0
	}

	return shifted + 1
}

func TickMathGetTickAtSqrtRatio(sqrtPriceX96 bigint) int32 {
	require(
		sqrtPriceX96 >= consts.MIN_SQRT_RATIO && sqrtPriceX96 < consts.MAX_SQRT_RATIO,
		ufmt.Sprintf("[POOL] sqrtPriceX96(%d) is out of range [%d, %d)", sqrtPriceX96, consts.MIN_SQRT_RATIO, consts.MAX_SQRT_RATIO),
	)
	ratio := sqrtPriceX96 << 32

	msb, adjustedRatio := findMSB(ratio)
	adjustedRatio = adjustRatio(ratio, msb)

	log2 := calculateLog2(msb, adjustedRatio)
	tick := getTickValue(log2, sqrtPriceX96)

	return tick
}

// findMSB computes the MSB (most significant bit) of the given ratio.
func findMSB(ratio bigint) (bigint, bigint) {
	msb := bigint(0)

	for i := 7; i >= 1; i-- {
		f := gt(ratio, binaryLogConsts[i]) << i
		msb = msb | bigint(f)
		ratio = ratio >> f
	}

	// handle the remaining bits
	{
		f := gt(ratio, 0x1)
		msb = msb | bigint(f)
	}

	return msb, ratio
}

// adjustRatio adjusts the given ratio based on the MSB found.
//
// This adjustment ensures that the ratio falls within the specific range.
func adjustRatio(ratio, msb bigint) bigint {
	if msb >= 128 {
		return ratio >> uint64(msb-127)
	}

	return ratio << uint64(127-msb)
}

// calculateLog2 calculates the binary logarith, of the adjusted ratio using a fixed-point arithmetic.
//
// This function iteratively squares the ratio and adjusts the result to compute the log base 2, which will determine the tick value.
func calculateLog2(msb, ratio bigint) bigint {
	log_2 := (msb - 128) << 64

	for i := 63; i >= 51; i-- {
		ratio = ratio * ratio >> 127
		f := ratio >> 128
		log_2 = log_2 | (f << i)
		ratio = ratio >> uint64(f)
	}

	// handle the remaining bits
	{
		ratio = ratio * ratio >> 127
		f := ratio >> 128
		log_2 = log_2 | (f << 50)
	}

	return log_2
}

// getTickValue determines the tick value corresponding to a given sqrtPriveX96.
//
// It calculates the upper and lower bounds for each tick, and selects the appropriate tock value
// based on the given sqrtPriceX96.
func getTickValue(log2, sqrtPriceX96 bigint) int32 {
	// ref: https://github.com/Uniswap/v3-core/issues/500
	// 2^64 / log2 (√1.0001) = 255738958999603826347141
	log_sqrt10001 := log2 * 255738958999603826347141

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.010000497 x 2^128 = 3402992956809132418596140100660247210
	tickLow := int32(int64((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128))

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.856 x 2^128 = 291339464771989622907027621153398088495
	tickHi := int32(int64((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128))

	var tick int32
	if tickLow == tickHi {
		tick = tickLow
	} else if TickMathGetSqrtRatioAtTick(tickHi) <= sqrtPriceX96 {
		tick = tickHi
	} else {
		tick = tickLow
	}

	return tick
}

func gt(x, y bigint) uint64 {
	if x > y {
		return 1
	}

	return 0
}

func absTick(n int32) bigint {
	if n < 0 {
		return -bigint(n)
	}

	return bigint(n)
}
