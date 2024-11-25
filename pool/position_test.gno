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
		expectedKey string
	}{
		{invalidAddr, 100, 200, true, `[GNOSWAP-POOL-023] invalid address || position.gno__positionGetKey() || invalid owner address invalidAddr`, ""},                                   // invalid address
		{validAddr, 200, 100, true, `[GNOSWAP-POOL-024] tickLower is greater than tickUpper || position.gno__positionGetKey() || tickLower(200) is greater than tickUpper(100)`, ""},     // tickLower > tickUpper
		{validAddr, -100, -200, true, `[GNOSWAP-POOL-024] tickLower is greater than tickUpper || position.gno__positionGetKey() || tickLower(-100) is greater than tickUpper(-200)`, ""}, // tickLower > tickUpper
		{validAddr, 100, 100, false, "", "ZzF3ZXNrYzZ0eWc5anhndWpsdGEwNDdoNmx0YTA0N2g2bGRqbHVkdV9fMTAwX18xMDA="},                                                                         // tickLower == tickUpper
		{validAddr, 100, 200, false, "", "ZzF3ZXNrYzZ0eWc5anhndWpsdGEwNDdoNmx0YTA0N2g2bGRqbHVkdV9fMTAwX18yMDA="},                                                                         // tickLower < tickUpper
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { positionGetKey(tc.owner, tc.tickLower, tc.tickUpper) })
		} else {
			key := positionGetKey(tc.owner, tc.tickLower, tc.tickUpper)
			uassert.Equal(t, tc.expectedKey, key)
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
		liquidity         *i256.Int
		amount0           *u256.Uint
		amount1           *u256.Uint
		shouldPanic       bool
		panicMsg          string
		expectedLiquidity string
	}{
		{i256.MustFromDecimal("0"), u256.Zero(), u256.Zero(), true, `[GNOSWAP-POOL-010] zero liquidity || position.gno__positionUpdate() || both liquidityDelta and current position's liquidity are zero`, ""},
		{i256.MustFromDecimal("100000"), u256.Zero(), u256.Zero(), false, "", "100000"},
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { dummyPool.positionUpdateWithKey(positionKey, tc.liquidity, tc.amount0, tc.amount1) })
		} else {
			newPos := dummyPool.positionUpdateWithKey(positionKey, tc.liquidity, tc.amount0, tc.amount1)
			uassert.Equal(t, newPos.liquidity.ToString(), tc.expectedLiquidity)
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
		expectedLiquidity    string
	}{
		{i256.MustFromDecimal("0"), u256.Zero(), u256.Zero(), true, `[GNOSWAP-POOL-010] zero liquidity || position.gno__positionUpdate() || both liquidityDelta and current position's liquidity are zero`, ""},
		{i256.MustFromDecimal("100000"), u256.Zero(), u256.Zero(), false, "", "100000"},
	}

	for _, tc := range tests {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { positionUpdate(position, tc.liquidityDelta, tc.feeGrowthInside0X128, tc.feeGrowthInside1X128) })
		} else {
			newPos := positionUpdate(position, tc.liquidityDelta, tc.feeGrowthInside0X128, tc.feeGrowthInside1X128)
			uassert.Equal(t, newPos.liquidity.ToString(), tc.expectedLiquidity)
		}
	}
}
