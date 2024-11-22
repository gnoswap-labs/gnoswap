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

	testStruct := []struct {
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

	for _, tc := range testStruct {
		if tc.shouldPanic {
			uassert.PanicsWithMessage(t, tc.panicMsg, func() { positionGetKey(tc.owner, tc.tickLower, tc.tickUpper) })
		} else {
			uassert.NotPanics(t, func() { positionGetKey(tc.owner, tc.tickLower, tc.tickUpper) })
		}
	}
}

func Test_positionUpdateWithKey(t *testing.T) {
	dummyPool := newPool(
		"token0",
		"token1",
		100,
		10,
		common.TickMathGetSqrtRatioAtTick(0),
	)

	positionKey := positionGetKey(
		testutils.TestAddress("dummyAddr"),
		100,
		200,
	)

	newPos := dummyPool.positionUpdateWithKey(
		positionKey,
		i256.MustFromDecimal("100000"),
		u256.Zero(),
		u256.Zero(),
	)

	uassert.Equal(t, newPos.liquidity.ToString(), "100000")
}
