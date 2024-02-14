package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

var tickRatioMap = map[bigint]bigint{
	0x1: 0xfffcb933bd6fad37aa2d162d1a594001,
	0x2: 0xfff97272373d413259a46990580e213a,
	0x4: 0xfff2e50f5f656932ef12357cf3c7fdcc,
	0x8: 0xffe5caca7e10e4e61c3624eaa0941cd0,
	0x10: 0xffcb9843d60f6159c9db58835c926644,
	0x20: 0xff973b41fa98c081472e6896dfb254c0,
	0x40: 0xff2ea16466c96a3843ec78b326b52861,
	0x80: 0xfe5dee046a99a2a811c461f1969c3053,
	0x100: 0xfcbe86c7900a88aedcffc83b479aa3a4,
	0x200: 0xf987a7253ac413176f2b074cf7815e54,
	0x400: 0xf3392b0822b70005940c7a398e4b70f3,
	0x800: 0xe7159475a2c29b7443b29c7fa6e889d9,
	0x1000: 0xd097f3bdfd2022b8845ad8f792aa5825,
	0x2000: 0xa9f746462d870fdf8a65dc1f90e061e5,
	0x4000: 0x70d869a156d2a1b890bb3df62baf32f7,
	0x8000: 0x31be135f97d08fd981231505542fcfa6,
	0x10000: 0x9aa508b5b7a84e1c677de54f3e99bc9,
	0x20000: 0x5d6af8dedb81196699c329225ee604,
	0x40000: 0x2216e584f5fa1ea926041bedfe98,
	0x80000: 0x48a170391f7dc42444e8fa2,
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
        fmt.Sprintf("[POOL] sqrtPriceX96(%d) is out of range [%d, %d)", sqrtPriceX96, consts.MIN_SQRT_RATIO, consts.MAX_SQRT_RATIO),
    )
	ratio := sqrtPriceX96 << 32

	r := ratio
	msb := bigint(0)

	// array
	_tv := [8]bigint{
		0x0,
		0x3,
		0xF,
		0xFF,
		0xFFFF,
		0xFFFFFFFF,
		0xFFFFFFFFFFFFFFFF,
		0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
	}

	for i := 7; i >= 1; i-- {
		f := gt(r, _tv[i]) << i
		msb = msb | bigint(f)
		r = r >> f
	}
	{
		f := gt(r, 0x1)
		msb = msb | bigint(f)
	}

	if msb >= 128 {
		r = ratio >> uint64(msb-127)
	} else {
		r = ratio << uint64(127-msb)
	}

	log_2 := (msb - 128) << 64

	for i := 63; i >= 51; i-- {
		r = r * r >> 127
		f := r >> 128
		log_2 = log_2 | (f << i)
		r = r >> uint64(f)
	}
	{
		r = r * r >> 127
		f := r >> 128
		log_2 = log_2 | (f << 50)
	}

	log_sqrt10001 := log_2 * 255738958999603826347141

	tickLow := int32(int64((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128))
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
