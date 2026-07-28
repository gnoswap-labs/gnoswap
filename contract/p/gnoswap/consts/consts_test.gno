package consts

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestUintConstructors(t *testing.T) {
	cases := []struct {
		name string
		got  *u256.Uint
		want string
	}{
		{"MaxUint256", MaxUint256(), "115792089237316195423570985008687907853269984665640564039457584007913129639935"},
		{"MaxUint128", MaxUint128(), "340282366920938463463374607431768211455"},
		{"MaxInt256", MaxInt256(), "57896044618658097711785492504343953926634992332820282019728792003956564819967"},
		{"Q96", Q96(), "79228162514264337593543950336"},
		{"Q128", Q128(), "340282366920938463463374607431768211456"},
		{"Q192", Q192(), "6277101735386680763835789423207666416102355444464034512896"},
		{"Max160", Max160(), "1461501637330902918203684832716283019655932542975"},
		{"MinSqrtRatio", MinSqrtRatio(), "4295128739"},
		{"MaxSqrtRatio", MaxSqrtRatio(), "1461446703485210103287273052203988822378723970342"},
	}
	for _, c := range cases {
		want := u256.MustFromDecimal(c.want)
		if !c.got.Eq(want) {
			t.Errorf("%s = %s, want %s", c.name, c.got.ToString(), c.want)
		}
	}
}

func TestIntConstructors(t *testing.T) {
	cases := []struct {
		name string
		got  *i256.Int
		want string
	}{
		{"MaxInt128I256", MaxInt128I256(), "170141183460469231731687303715884105727"},
		{"MaxInt64I256", MaxInt64I256(), "9223372036854775807"},
		{"MinInt64I256", MinInt64I256(), "-9223372036854775808"},
	}
	for _, c := range cases {
		want := i256.MustFromDecimal(c.want)
		if c.got.Neq(want) {
			t.Errorf("%s = %s, want %s", c.name, c.got.ToString(), c.want)
		}
	}
}

// TestFreshInstances confirms each constructor returns a distinct pointer so
// callers can never share (and accidentally mutate) a singleton backing value.
func TestFreshInstances(t *testing.T) {
	a := Q128()
	b := Q128()
	if a == b {
		t.Error("Q128() returned the same pointer twice")
	}
	// Mutating one must not affect the other.
	a.SetUint64(1)
	if b.Eq(a) {
		t.Error("mutating one Q128() instance affected another")
	}

	ia := MaxInt64I256()
	ib := MaxInt64I256()
	if ia == ib {
		t.Error("MaxInt64I256() returned the same pointer twice")
	}
}
