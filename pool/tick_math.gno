package pool

import (
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	var absTick *u256.Uint
	if tick < 0 {
		absTick = u256.NewUint(uint64(-tick))
	} else {
		absTick = u256.NewUint(uint64(tick))
	}

	require(!absTick.Lte(u256.NewUint(uint64(consts.MAX_TICK))), ufmt.Sprintf("[POOL] tick_math.gno__TickMathGetSqrtRatioAtTick() || Tick out of range [absTick(%s) <= MAX_TICK(%d)]", absTick.Dec(), consts.MAX_TICK))

	var ratio *u256.Uint
	if !new(u256.Uint).And(absTick, u256.NewUint(0x1)).IsZero() {
		ratio = u256.FromBigint(0xfffcb933bd6fad37aa2d162d1a594001)
	} else {
		ratio = u256.FromBigint(0x100000000000000000000000000000000)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x2)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xfff97272373d413259a46990580e213a))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x4)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xfff2e50f5f656932ef12357cf3c7fdcc))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x8)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xffe5caca7e10e4e61c3624eaa0941cd0))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x10)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xffcb9843d60f6159c9db58835c926644))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x20)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xff973b41fa98c081472e6896dfb254c0))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x40)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xff2ea16466c96a3843ec78b326b52861))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x80)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xfe5dee046a99a2a811c461f1969c3053))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x100)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xfcbe86c7900a88aedcffc83b479aa3a4))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x200)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xf987a7253ac413176f2b074cf7815e54))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x400)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xf3392b0822b70005940c7a398e4b70f3))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x800)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xe7159475a2c29b7443b29c7fa6e889d9))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x1000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xd097f3bdfd2022b8845ad8f792aa5825))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x2000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0xa9f746462d870fdf8a65dc1f90e061e5))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x4000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x70d869a156d2a1b890bb3df62baf32f7))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x8000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x31be135f97d08fd981231505542fcfa6))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x10000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x9aa508b5b7a84e1c677de54f3e99bc9))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x20000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x5d6af8dedb81196699c329225ee604))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x40000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x2216e584f5fa1ea926041bedfe98))
		ratio.Rsh(ratio, 128)
	}

	if !new(u256.Uint).And(absTick, u256.NewUint(0x80000)).IsZero() {
		ratio.Mul(ratio, u256.FromBigint(0x48a170391f7dc42444e8fa2))
		ratio.Rsh(ratio, 128)
	}

	if tick > 0 {
		ratio.Div(u256.FromBigint(consts.MAX_UINT256), ratio)
	}

	shiftedRatio := new(u256.Uint).Rsh(ratio, 32)

	remainder := new(u256.Uint).Mod(ratio, u256.NewUint(1<<32))

	if new(u256.Uint).Add(shiftedRatio, remainder).IsZero() {
		return shiftedRatio
	} else {
		return shiftedRatio.Add(shiftedRatio, u256.One())
	}
}

func TickMathGetTickAtSqrtRatio(sqrtPriceX96 *u256.Uint) int32 {
	require(sqrtPriceX96.Gte(u256.FromBigint(consts.MIN_SQRT_RATIO)) && sqrtPriceX96.Lt(u256.FromBigint(consts.MAX_SQRT_RATIO)), ufmt.Sprintf("[POOL] tick_math.gno__tickMathGetTickAtSqrtRatio() || Tick out of range [sqrtPriceX96(%s) >= MIN_SQRT_RATIO(%d) && sqrtPriceX96(%s) < MAX_SQRT_RATIO(%d)]", sqrtPriceX96.Dec(), consts.MIN_SQRT_RATIO, sqrtPriceX96.Dec(), consts.MAX_SQRT_RATIO))
	ratio := new(u256.Uint).Lsh(sqrtPriceX96, 32)

	r := ratio.Clone()
	msb := uint64(0)

	// array
	_tv := [8]*u256.Uint{
		u256.FromBigint(0),
		u256.FromBigint(3),
		u256.FromBigint(15),
		u256.FromBigint(255),
		u256.FromBigint(65535),
		u256.FromBigint(4294967295),
		u256.FromBigint(18446744073709551615),
		u256.FromBigint(340282366920938463463374607431768211455),
	}

	for i := 7; i >= 1; i-- {
		f := gt(r, _tv[i]) << uint(i)
		msb = msb | f
		r.Rsh(r, uint(f))
	}
	{
		f := gt(r, u256.One())
		msb = msb | f
	}

	if msb >= 128 {
		r = new(u256.Uint).Rsh(ratio, uint(msb-127))
	} else {
		r = new(u256.Uint).Lsh(ratio, uint(127-msb))
	}

	log_2 := u256.NewInt(int64(msb - 128))
	log_2.Lsh(log_2, 64) // -18446744073709551616

	for i := 63; i >= 51; i-- {

		r.Mul(r, r)
		r.Rsh(r, 127)
		f := new(u256.Uint).Rsh(r, 128)

		_temp := new(u256.Uint).Lsh(f, uint(i))

		log_2.Or(log_2, new(u256.Uint).Lsh(f, uint(i)).Int())

		r.Rsh(r, uint(f.Uint64())) // XXXXXXXXX possibly overflow
	}

	{
		r.Mul(r, r)
		r.Rsh(r, 127)
		f := new(u256.Uint).Rsh(r, 128)
		log_2.Or(log_2, new(u256.Uint).Lsh(f, uint(50)).Int())
	}

	log_sqrt10001 := new(u256.Int).Mul(log_2, u256.FromBigint(255738958999603826347141).Int())

	tickLow256 := new(u256.Int).Sub(log_sqrt10001, u256.FromBigint(3402992956809132418596140100660247210).Int())
	tickLow256.Rsh(tickLow256, 128)
	tickLow := int32(tickLow256.Int64()) // XXXXX: needs to be checked if bound

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
