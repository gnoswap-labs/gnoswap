package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/json"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"

	"gno.land/p/demo/testutils"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	got      *u256.Uint
	x        *u256.Uint
	y        *i256.Int
	expected *u256.Uint
	rst      bool
)

func TestAddDelta_1(t *testing.T) {
	// 1+0
	x = u256.NewUint(1)
	y = i256.NewInt(0)
	got = LiquidityMathAddDelta(x, y)
	expected = u256.NewUint(1)

	rst = got.Eq(expected)
	if !rst {
		t.Errorf("Test Liquidity Math #1: 1 + 0 is failed")
	}
}

func TestAddDelta_2(t *testing.T) {
	// 1+-1
	x = u256.NewUint(1)
	y = i256.NewInt(-1)
	got = LiquidityMathAddDelta(x, y)
	expected = u256.NewUint(0)
	rst = got.Eq(expected)

	rst = got.Eq(expected)
	if !rst {
		t.Errorf("Test Liquidity Math #2: 1 + -1 is failed")
	}
}

func TestAddDelta_3(t *testing.T) {
	// 1+1
	x = u256.NewUint(1)
	y = i256.NewInt(1)
	got = LiquidityMathAddDelta(x, y)
	expected = u256.NewUint(2)
	rst = got.Eq(expected)
	if !rst {
		t.Errorf("Test Liquidity Math #3: 1 + 1 is failed")
	}
}

func TestAddDelta_4(t *testing.T) {
	// 2**128-15 + 15
	x = u256.MustFromDecimal("340282366920938463463374607431768211441") // 340282366920938463463374607431768211441 = 2**128-15
	if x.ToString() != "340282366920938463463374607431768211441" {
		t.Errorf("u256 is failed !")
	}

	y = i256.NewInt(15)
	got = LiquidityMathAddDelta(x, y)
	expected = u256.MustFromDecimal("340282366920938463463374607431768211456") // 2**128
	rst = got.Eq(expected)

	rst = got.Eq(expected)
	if !rst {
		t.Errorf("Test Liquidity Math #4: 2**128-15 + 15 is failed")
	}
}

func TestAddDelta_5(t *testing.T) {
	// 0+-1 underflow
	x = u256.NewUint(0)
	y = i256.NewInt(-1)
	shouldPanicWithMsg(
		t,
		func() {
			LiquidityMathAddDelta(x, y)
		},
		"LS",
	)
}

func TestAddDelta_6(t *testing.T) {
	// 3+-4 underflow
	x = u256.NewUint(3)
	y = i256.NewInt(-4)
	shouldPanicWithMsg(
		t,
		func() {
			LiquidityMathAddDelta(x, y)
		},
		"LS",
	)
}

func LiquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	return liquidityMathAddDelta(x, y)
}
