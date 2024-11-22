package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
)

func TestPositionGetKey(t *testing.T) {
	invalidAddr := std.Address("invalidAddr")
	validAddr := testutils.TestAddress("validAddr")

	tests := []struct {
		owner       std.Address
		tickLower   int32
		tickUpper   int32
		shouldPanic bool
		panicMsg    string
	}{
		{invalidAddr, 100, 200, true, `[GNOSWAP-POOL-023] invalid address || position.gno__positionGetKey() || invalid owner address invalidAddr`},                                   // invalid address
		{validAddr, 200, 100, true, `[GNOSWAP-POOL-024] tickLower is greater than tickUpper || position.gno__positionGetKey() || tickLower(200) is greater than tickUpper(100)`},     // tickLower > tickUpper
		{validAddr, -100, -200, true, `[GNOSWAP-POOL-024] tickLower is greater than tickUpper || position.gno__positionGetKey() || tickLower(-100) is greater than tickUpper(-200)`}, // tickLower > tickUpper
		{validAddr, 100, 100, false}, // tickLower == tickUpper
		{validAddr, 100, 200, false}, // tickLower < tickUpper
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { positionGetKey(tc.owner, tc.tickLower, tc.tickUpper) })
		} else {
			uassert.NotPanics(t, func() { positionGetKey(tc.owner, tc.tickLower, tc.tickUpper) })
		}
	}
}

func TestPositionUpdateWithKey(t *testing.T) {
	var dummyPool *Pool
	var positionKey string

	t.Run("set up initial data for this test function", func(t *testing.T) {
		dummyPool = newPool(
			"token0",
			"token1",
			100,
			10,
			common.TickMathGetSqrtRatioAtTick(0),
		)

		positionKey = positionGetKey(
			testutils.TestAddress("dummyAddr"),
			100,
			200,
		)
	})

	tests := []struct {
		liquidity   *i256.Int
		amount0     *u256.Uint
		amount1     *u256.Uint
		shouldPanic bool
		panicMsg    string
	}{
		{i256.MustFromDecimal("0"), u256.Zero(), u256.Zero(), true, `[GNOSWAP-POOL-010] zero liquidity || position.gno__positionUpdate() || both liquidityDelta and current position's liquidity are zero`},
		{i256.MustFromDecimal("100000"), u256.Zero(), u256.Zero(), false, ``},
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { dummyPool.positionUpdateWithKey(positionKey, tc.liquidity, tc.amount0, tc.amount1) })
		} else {
			var newPos PositionInfo
			uassert.NotPanics(t, func() { newPos = dummyPool.positionUpdateWithKey(positionKey, tc.liquidity, tc.amount0, tc.amount1) })
			uassert.Equal(t, newPos.liquidity.ToString(), "100000")
		}
	}
}

func TestPositionUpdate(t *testing.T) {
	position := PositionInfo{
		liquidity: u256.Zero(),
	}

	tests := []struct {
		liquidityDelta       *i256.Int
		feeGrowthInside0X128 *u256.Uint
		feeGrowthInside1X128 *u256.Uint
		shouldPanic          bool
		panicMsg             string
	}{
		{i256.MustFromDecimal("0"), u256.Zero(), u256.Zero(), true, `[GNOSWAP-POOL-010] zero liquidity || position.gno__positionUpdate() || both liquidityDelta and current position's liquidity are zero`},
		{i256.MustFromDecimal("100000"), u256.Zero(), u256.Zero(), false, ``},
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { positionUpdate(position, tc.liquidityDelta, tc.feeGrowthInside0X128, tc.feeGrowthInside1X128) })
		} else {
			uassert.NotPanics(t, func() { positionUpdate(position, tc.liquidityDelta, tc.feeGrowthInside0X128, tc.feeGrowthInside1X128) })
		}
	}
}
