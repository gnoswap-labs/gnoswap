package swap_scneraio

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/grc/grc721"

	"gno.land/r/demo/users"

	"gno.land/r/demo/wugnot"
)

const (
	MAX_UINT256 bigint = 115792089237316195423570985008687907853269984665640564039457584007913129639935
)

func balanceOf(token *grc20.AdminToken, addr std.Address) uint64 {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}

	return balance
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || unsupported tokenId type")
	}
}

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}

func wugnotBalanceOf(addr std.Address) uint64 {
	return wugnot.BalanceOf(a2u(addr))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

func getSqrtRatioAtTick(tick int32) bigint {
	var absTick bigint
	if tick < 0 {
		absTick = -1 * bigint(tick)
	} else {
		absTick = bigint(tick)
	}

	var ratio bigint
	if absTick&0x1 != 0 {
		ratio = 0xfffcb933bd6fad37aa2d162d1a594001
	} else {
		ratio = 0x100000000000000000000000000000000
	}

	if absTick&0x2 != 0 {
		ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128
	}
	if absTick&0x4 != 0 {
		ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128
	}
	if absTick&0x8 != 0 {
		ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128
	}
	if absTick&0x10 != 0 {
		ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128
	}
	if absTick&0x20 != 0 {
		ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128
	}
	if absTick&0x40 != 0 {
		ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128
	}
	if absTick&0x80 != 0 {
		ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128
	}
	if absTick&0x100 != 0 {
		ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128
	}
	if absTick&0x200 != 0 {
		ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128
	}
	if absTick&0x400 != 0 {
		ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128
	}
	if absTick&0x800 != 0 {
		ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128
	}
	if absTick&0x1000 != 0 {
		ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128
	}
	if absTick&0x2000 != 0 {
		ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128
	}
	if absTick&0x4000 != 0 {
		ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128
	}
	if absTick&0x8000 != 0 {
		ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128
	}
	if absTick&0x10000 != 0 {
		ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128
	}
	if absTick&0x20000 != 0 {
		ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128
	}
	if absTick&0x40000 != 0 {
		ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128
	}
	if absTick&0x80000 != 0 {
		ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128
	}

	if tick > 0 {
		ratio = MAX_UINT256 / ratio
	}

	shiftedRatio := ratio >> 32
	remainder := ratio % (1 << 32)
	if remainder == 0 {
		return shiftedRatio + 0
	} else {
		return shiftedRatio + 1
	}
}

func getTickAtSqrtRatio(sqrtPriceX96 bigint) int32 {
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

	tick := tickLow
	if tickLow == tickHi {
		if getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 {
			tick = tickHi
		}
	}

	return tick
}

func gt(x, y bigint) uint64 {
	if x > y {
		return 1
	} else {
		return 0
	}
}
