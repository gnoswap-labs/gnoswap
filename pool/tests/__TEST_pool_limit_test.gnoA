package pool

import (
	"std"
	"testing"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
)

var (
	test_tickLower          = int32(-6000)
	test_tickUpper          = int32(6000)
	test_liquidityExpectStr = "10000000000"
)

// XXX: how to re produce `thru` ??
func TestLimitOrder(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)
	CreatePool(barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	thisPool := GetPool(barPath, fooPath, fee100)

	t.Run("limit selling 0 for 1 at tick 0 thru 1", func(t *testing.T) {
		std.TestSetRealm(posRealm)
		amount0, amount1 := Mint(
			barPath,
			fooPath,
			fee100,
			consts.POSITION_ADDR.String(),
			0,
			120,
			test_liquidityExpectStr,
		)
		shouldNEQ(t, amount0, "0")
		shouldEQ(t, amount1, "0")

		std.TestSetRealm(rouRealm)
		result0, result1 := Swap(
			barPath,
			fooPath,
			fee100,
			gsa.String(),
			false,
			"1000000",
			consts.MAX_PRICE,
			std.GetOrigCaller().String(),
		)
		slotTick := thisPool.slot0.tick
	})
}
