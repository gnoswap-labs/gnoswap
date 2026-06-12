package gnsmath

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestSafeAddInt64(t *testing.T) {
	uassert.Equal(t, int64(3), SafeAddInt64(1, 2))
	uassert.Equal(t, int64(-3), SafeAddInt64(-1, -2))
	uassert.Equal(t, int64(math.MaxInt64), SafeAddInt64(math.MaxInt64-1, 1))
	uassert.Equal(t, int64(math.MinInt64), SafeAddInt64(math.MinInt64+1, -1))
}

func TestSafeAddInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "int64 addition overflow", func() {
		SafeAddInt64(math.MaxInt64, 1)
	})
	uassert.PanicsWithMessage(t, cur, "int64 addition underflow", func() {
		SafeAddInt64(math.MinInt64, -1)
	})
}

func TestSafeSubInt64(t *testing.T) {
	uassert.Equal(t, int64(-1), SafeSubInt64(1, 2))
	uassert.Equal(t, int64(math.MaxInt64), SafeSubInt64(math.MaxInt64, 0))
	uassert.Equal(t, int64(math.MinInt64), SafeSubInt64(math.MinInt64+1, 1))
}

func TestSafeSubInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "int64 subtraction underflow", func() {
		SafeSubInt64(math.MinInt64, 1)
	})
	uassert.PanicsWithMessage(t, cur, "int64 subtraction overflow", func() {
		SafeSubInt64(math.MaxInt64, -1)
	})
}

func TestSafeMulInt64(t *testing.T) {
	uassert.Equal(t, int64(0), SafeMulInt64(0, 123))
	uassert.Equal(t, int64(6), SafeMulInt64(2, 3))
	uassert.Equal(t, int64(6), SafeMulInt64(-2, -3))
	uassert.Equal(t, int64(-6), SafeMulInt64(2, -3))
	uassert.Equal(t, int64(-6), SafeMulInt64(-2, 3))
}

func TestSafeMulInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "int64 multiplication overflow", func() {
		SafeMulInt64(math.MaxInt64, 2)
	})
	uassert.PanicsWithMessage(t, cur, "int64 multiplication overflow", func() {
		SafeMulInt64(math.MinInt64, -1)
	})
	uassert.PanicsWithMessage(t, cur, "int64 multiplication underflow", func() {
		SafeMulInt64(math.MaxInt64, -2)
	})
	uassert.PanicsWithMessage(t, cur, "int64 multiplication underflow", func() {
		SafeMulInt64(math.MinInt64, 2)
	})
}

func TestSafeMulDivInt64(t *testing.T) {
	uassert.Equal(t, int64(0), SafeMulDivInt64(0, 5, 2))
	uassert.Equal(t, int64(6), SafeMulDivInt64(4, 3, 2))

	// product exceeds int64 but quotient fits — native int64 would overflow,
	// the 256-bit intermediate keeps it correct.
	uassert.Equal(t, int64(math.MaxInt64), SafeMulDivInt64(math.MaxInt64, 4, 4))
}

func TestSafeMulDivInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, errSafeMathOverflow, func() {
		SafeMulDivInt64(math.MaxInt64, 4, 1)
	})
}

func TestSafeAbsInt64(t *testing.T) {
	uassert.Equal(t, int64(5), SafeAbsInt64(5))
	uassert.Equal(t, int64(5), SafeAbsInt64(-5))
	uassert.Equal(t, int64(0), SafeAbsInt64(0))
}

func TestSafeAbsInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, errSafeMathOverflow, func() {
		SafeAbsInt64(math.MinInt64)
	})
}

func TestSafeAddUint64(t *testing.T) {
	uassert.Equal(t, uint64(3), SafeAddUint64(1, 2))
	uassert.Equal(t, uint64(math.MaxUint64), SafeAddUint64(math.MaxUint64-1, 1))
}

func TestSafeAddUint64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "uint64 addition overflow", func() {
		SafeAddUint64(math.MaxUint64, 1)
	})
}

func TestSafeSubUint64(t *testing.T) {
	uassert.Equal(t, uint64(1), SafeSubUint64(3, 2))
	uassert.Equal(t, uint64(0), SafeSubUint64(2, 2))
}

func TestSafeSubUint64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "uint64 subtraction underflow", func() {
		SafeSubUint64(1, 2)
	})
}

func TestSafeUint64ToInt64(t *testing.T) {
	uassert.Equal(t, int64(123), SafeUint64ToInt64(123))
	uassert.Equal(t, int64(math.MaxInt64), SafeUint64ToInt64(uint64(math.MaxInt64)))
}

func TestSafeUint64ToInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur,
		"amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
		func() {
			SafeUint64ToInt64(uint64(math.MaxInt64) + 1)
		})
}

func TestSafeConvertToInt64(t *testing.T) {
	uassert.Equal(t, int64(123), SafeConvertToInt64(u256.NewUint(123)))
	uassert.Equal(t, int64(math.MaxInt64),
		SafeConvertToInt64(u256.MustFromDecimal(maxInt64Decimal)))
}

func TestSafeConvertToInt64_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "SafeConvertToInt64: value is nil", func() {
		SafeConvertToInt64(nil)
	})
	uassert.PanicsWithMessage(t, cur,
		"amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
		func() {
			SafeConvertToInt64(u256.MustFromDecimal("9223372036854775808"))
		})
}

func TestSafeConvertToInt128(t *testing.T) {
	got := SafeConvertToInt128(u256.NewUint(123))
	uassert.Equal(t, "123", got.ToString())

	maxOk := SafeConvertToInt128(u256.MustFromDecimal(maxInt128Decimal))
	uassert.Equal(t, maxInt128Decimal, maxOk.ToString())
}

func TestSafeConvertToInt128_Panics(cur realm, t *testing.T) {
	uassert.PanicsWithMessage(t, cur, "SafeConvertToInt128: value is nil", func() {
		SafeConvertToInt128(nil)
	})
	uassert.PanicsWithMessage(t, cur,
		"amount(170141183460469231731687303715884105728) overflows int128 range",
		func() {
			SafeConvertToInt128(u256.MustFromDecimal("170141183460469231731687303715884105728"))
		})
}
