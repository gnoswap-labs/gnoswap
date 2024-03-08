package common

import (
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

var tickRatioMap = map[uint64]*u256.Uint{
	0x1:     u256.FromBigint(0xfffcb933bd6fad37aa2d162d1a594001),
	0x2:     u256.FromBigint(0xfff97272373d413259a46990580e213a),
	0x4:     u256.FromBigint(0xfff2e50f5f656932ef12357cf3c7fdcc),
	0x8:     u256.FromBigint(0xffe5caca7e10e4e61c3624eaa0941cd0),
	0x10:    u256.FromBigint(0xffcb9843d60f6159c9db58835c926644),
	0x20:    u256.FromBigint(0xff973b41fa98c081472e6896dfb254c0),
	0x40:    u256.FromBigint(0xff2ea16466c96a3843ec78b326b52861),
	0x80:    u256.FromBigint(0xfe5dee046a99a2a811c461f1969c3053),
	0x100:   u256.FromBigint(0xfcbe86c7900a88aedcffc83b479aa3a4),
	0x200:   u256.FromBigint(0xf987a7253ac413176f2b074cf7815e54),
	0x400:   u256.FromBigint(0xf3392b0822b70005940c7a398e4b70f3),
	0x800:   u256.FromBigint(0xe7159475a2c29b7443b29c7fa6e889d9),
	0x1000:  u256.FromBigint(0xd097f3bdfd2022b8845ad8f792aa5825),
	0x2000:  u256.FromBigint(0xa9f746462d870fdf8a65dc1f90e061e5),
	0x4000:  u256.FromBigint(0x70d869a156d2a1b890bb3df62baf32f7),
	0x8000:  u256.FromBigint(0x31be135f97d08fd981231505542fcfa6),
	0x10000: u256.FromBigint(0x9aa508b5b7a84e1c677de54f3e99bc9),
	0x20000: u256.FromBigint(0x5d6af8dedb81196699c329225ee604),
	0x40000: u256.FromBigint(0x2216e584f5fa1ea926041bedfe98),
	0x80000: u256.FromBigint(0x48a170391f7dc42444e8fa2),
}

var binaryLogConsts = [8]*u256.Uint{
	u256.FromBigint(0x0),
	u256.FromBigint(0x3),
	u256.FromBigint(0xF),
	u256.FromBigint(0xFF),
	u256.FromBigint(0xFFFF),
	u256.FromBigint(0xFFFFFFFF),
	u256.FromBigint(0xFFFFFFFFFFFFFFFF),
	u256.FromBigint(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
}

func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	absTick := absTick(tick)
	require(
		absTick <= uint64(consts.MAX_TICK),
		ufmt.Sprintf(
			"[POOL] tick_math.gno__TickMathGetSqrtRatioAtTick() || absTick(%d) <= consts.MAX_TICK(%d)",
			absTick, consts.MAX_TICK,
		),
	)

	ratio := u256.FromBigint(consts.Q128)
	for mask, value := range tickRatioMap {
		if absTick&mask != 0 {
			ratio.Mul(ratio, value)
			ratio.Rsh(ratio, 128)
		}
	}

	if tick > 0 {
		ratio.Div(u256.FromBigint(consts.Q96), ratio)
	}

	shifted := new(u256.Uint).Rsh(ratio, 32)
	remainder := new(u256.Uint).Mod(ratio, u256.NewUint(1<<32))

	if new(u256.Uint).Add(shifted, remainder).IsZero() {
		return shifted
	}

	return shifted.Add(shifted, u256.One())
}

func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	require(
		sqrtPriceX96.Gte(u256.FromBigint(consts.MIN_SQRT_RATIO)) && sqrtPriceX96.Lt(u256.FromBigint(consts.MAX_SQRT_RATIO)),
		ufmt.Sprintf("[POOL] sqrtPriceX96(%d) is out of range [%d, %d)", sqrtPriceX96.Dec(), consts.MIN_SQRT_RATIO, consts.MAX_SQRT_RATIO))
	ratio := new(u256.Uint).Lsh(sqrtPriceX96, 32)

	msb, adjustedRatio := findMSB(ratio)
	adjustedRatio = adjustRatio(ratio, msb)

	log2 := calculateLog2(msb, adjustedRatio)
	tick := getTickValue(log2, sqrtPriceX96)

	return tick
}

// findMSB computes the MSB (most significant bit) of the given ratio.
func findMSB(ratio *u256.Uint) (uint64, *u256.Uint) {
	msb := uint64(0)

	for i := 7; i >= 1; i-- {
		f := gt(ratio, binaryLogConsts[i]) << i
		msb = msb | f
		ratio.Rsh(ratio, uint(f))
	}

	// handle the remaining bits
	{
		f := gt(ratio, u256.One())
		msb = msb | f
	}

	return msb, ratio
}

// adjustRatio adjusts the given ratio based on the MSB found.
//
// This adjustment ensures that the ratio falls within the specific range.
func adjustRatio(ratio *u256.Uint, msb uint64) *u256.Uint {
	if msb >= 128 {
		return new(u256.Uint).Rsh(ratio, uint(msb-127))
	}

	return new(u256.Uint).Lsh(ratio, uint(127-msb))
}

// calculateLog2 calculates the binary logarith, of the adjusted ratio using a fixed-point arithmetic.
//
// This function iteratively squares the ratio and adjusts the result to compute the log base 2, which will determine the tick value.
func calculateLog2(msb uint64, ratio *u256.Uint) *u256.Int {
	log_2 := u256.NewInt(int64(msb - 128))
	log_2.Lsh(log_2, 64)

	for i := 63; i >= 51; i-- {
		ratio.Mul(ratio, ratio)
		ratio.Rsh(ratio, 127)
		f := new(u256.Uint).Rsh(ratio, 128)
		log_2.Or(log_2, new(u256.Uint).Lsh(f, uint(i)).Int())
		ratio.Rsh(ratio, uint(f.Uint64())) // XXXXXXXXX possibly overflow
	}

	// handle the remaining bits
	{
		ratio.Mul(ratio, ratio)
		ratio.Rsh(ratio, 127)
		f := new(u256.Uint).Rsh(ratio, 128)
		log_2.Or(log_2, new(u256.Uint).Lsh(f, uint(50)).Int())
	}

	return log_2
}

// getTickValue determines the tick value corresponding to a given sqrtPriveX96.
//
// It calculates the upper and lower bounds for each tick, and selects the appropriate tock value
// based on the given sqrtPriceX96.
func getTickValue(log2 *u256.Int, sqrtPriceX96 *u256.Uint) int32 {
	// ref: https://github.com/Uniswap/v3-core/issues/500
	// 2^64 / log2 (√1.0001) = 255738958999603826347141
	log_sqrt10001 := new(u256.Int).Mul(log2, u256.FromBigint(255738958999603826347141).Int())

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.010000497 x 2^128 = 3402992956809132418596140100660247210
	tickLow256 := new(u256.Int).Sub(log_sqrt10001, u256.FromBigint(3402992956809132418596140100660247210).Int())
	tickLow256.Rsh(tickLow256, 128)
	tickLow := int32(tickLow256.Int64()) // XXXXX: needs to be checked if bound

	// ref: https://ethereum.stackexchange.com/questions/113844/how-does-uniswap-v3s-logarithm-library-tickmath-sol-work/113912#113912
	// 0.856 x 2^128 = 291339464771989622907027621153398088495
	tickHi256 := new(u256.Int).Add(log_sqrt10001, u256.FromBigint(291339464771989622907027621153398088495).Int())
	tickHi256.Rsh(tickHi256, 128)
	tickHi := int32(tickHi256.Int64()) // XXXXX: needs to be checked if bound

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

func gt(x, y *u256.Uint) uint64 {
	if x.Gt(y) {
		return 1
	} else {
		return 0
	}
}

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func absTick(n int32) uint64 {
	if n < 0 {
		return uint64(-n)
	}

	return uint64(n)
}
