package gnsmath

import (
	"math"

	ufmt "gno.land/p/nt/ufmt/v0"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Range bounds used by the safe conversion helpers.
const (
	maxInt64Decimal  = "9223372036854775807"                     // 2^63 - 1
	maxInt128Decimal = "170141183460469231731687303715884105727" // 2^127 - 1
)

// maxInt128 is the largest value representable in a signed 128-bit integer.
// It is used by SafeConvertToInt128 to bound liquidity deltas.
func MaxInt128() *i256.Int {
	return i256.MustFromDecimal(maxInt128Decimal)
}

// SafeAddInt64 returns a + b, panicking on int64 overflow or underflow.
func SafeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}
	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}
	return a + b
}

// SafeSubInt64 returns a - b, panicking on int64 overflow or underflow.
func SafeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}
	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}
	return a - b
}

// SafeMulInt64 returns a * b, panicking on int64 overflow or underflow.
func SafeMulInt64(a, b int64) int64 {
	if a == 0 || b == 0 {
		return 0
	}

	if a > 0 && b > 0 {
		if a > math.MaxInt64/b {
			panic("int64 multiplication overflow")
		}
	} else if a < 0 && b < 0 {
		if a < math.MaxInt64/b {
			panic("int64 multiplication overflow")
		}
	} else if a > 0 && b < 0 {
		if b < math.MinInt64/a {
			panic("int64 multiplication underflow")
		}
	} else { // a < 0 && b > 0
		if a < math.MinInt64/b {
			panic("int64 multiplication underflow")
		}
	}

	return a * b
}

// SafeMulDiv returns (a * b) / c using native int64 arithmetic.
// It panics on multiplication overflow/underflow or division by zero.
//
// Unlike SafeMulDivInt64 the intermediate product is kept in int64, so the
// product a*b must itself fit in int64.
func SafeMulDiv(a, b, c int64) int64 {
	if c == 0 {
		panic("division by zero in SafeMulDiv")
	}

	if a != 0 && b != 0 {
		if a > 0 && b > 0 && a > math.MaxInt64/b {
			panic("int64 multiplication overflow in SafeMulDiv")
		}
		if a > 0 && b < 0 && b < math.MinInt64/a {
			panic("int64 multiplication underflow in SafeMulDiv")
		}
		if a < 0 && b > 0 && a < math.MinInt64/b {
			panic("int64 multiplication underflow in SafeMulDiv")
		}
		if a < 0 && b < 0 && a < math.MaxInt64/b {
			panic("int64 multiplication overflow in SafeMulDiv")
		}
	}

	return (a * b) / c
}

// SafeMulDivInt64 returns (a * b) / c, computing the intermediate product in
// 256-bit signed arithmetic so a*b need not fit in int64. The final quotient
// must fit in int64, otherwise it panics. It panics on overflow.
func SafeMulDivInt64(a, b, c int64) int64 {
	if a == 0 || b == 0 {
		return 0
	}

	result, overflow := i256.Zero().MulOverflow(i256.NewInt(a), i256.NewInt(b))
	if overflow {
		panic(errSafeMathOverflow)
	}

	result = i256.Zero().Div(result, i256.NewInt(c))
	if !result.IsInt64() {
		panic(errSafeMathOverflow)
	}

	return result.Int64()
}

// SafeAbsInt64 returns the absolute value of a, panicking when a is math.MinInt64
// since its absolute value is not representable in int64.
func SafeAbsInt64(a int64) int64 {
	if a == math.MinInt64 {
		panic(errSafeMathOverflow)
	}
	if a < 0 {
		return -a
	}
	return a
}

// SafeAddUint64 returns a + b, panicking on uint64 overflow.
func SafeAddUint64(a, b uint64) uint64 {
	if a > math.MaxUint64-b {
		panic("uint64 addition overflow")
	}
	return a + b
}

// SafeSubUint64 returns a - b, panicking on uint64 underflow.
func SafeSubUint64(a, b uint64) uint64 {
	if a < b {
		panic("uint64 subtraction underflow")
	}
	return a - b
}

// SafeUint64ToInt64 converts a uint64 to int64, panicking when the value
// exceeds the int64 range (2^63 - 1).
func SafeUint64ToInt64(value uint64) int64 {
	if value > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf(
			"amount(%d) overflows int64 range (max: %s)",
			value, maxInt64Decimal,
		))
	}
	return int64(value)
}

// SafeConvertToInt64 converts a *u256.Uint to int64, panicking when the value
// is nil or exceeds the int64 range (2^63 - 1).
func SafeConvertToInt64(value *u256.Uint) int64 {
	if value == nil {
		panic("SafeConvertToInt64: value is nil")
	}
	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max: %s)",
			value.ToString(), maxInt64Decimal,
		))
	}
	return int64(res)
}

// SafeConvertToInt128 converts a *u256.Uint to an *i256.Int, panicking when the
// value exceeds the signed int128 range (2^127 - 1).
func SafeConvertToInt128(value *u256.Uint) *i256.Int {
	if value == nil {
		panic("SafeConvertToInt128: value is nil")
	}
	converted := i256.FromUint256(value)
	if converted.Gt(MaxInt128()) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int128 range",
			value.ToString(),
		))
	}
	return converted
}
