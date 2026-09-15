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

// MaxInt128 returns the largest positive value representable by a signed 128-bit integer.
//
// Returns:
//   - maxInt128: A fresh *i256.Int containing 2^127 - 1, used as the upper bound
//     for conversions that must fit in the signed int128 range.
func MaxInt128() *i256.Int {
	return i256.MustFromDecimal(maxInt128Decimal)
}

// SafeAddInt64 returns the exact sum of two signed 64-bit integers.
//
// Parameters:
//   - a: First signed int64 operand.
//   - b: Second signed int64 operand.
//
// Returns:
//   - sum: a + b when the mathematical result is within [math.MinInt64, math.MaxInt64].
//
// Panics if the signed int64 sum overflows or underflows.
func SafeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}
	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}
	return a + b
}

// SafeSubInt64 returns the exact difference of two signed 64-bit integers.
//
// Parameters:
//   - a: Signed int64 minuend.
//   - b: Signed int64 subtrahend.
//
// Returns:
//   - difference: a - b when the mathematical result is within [math.MinInt64, math.MaxInt64].
//
// Panics if the signed int64 difference overflows or underflows.
func SafeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}
	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}
	return a - b
}

// SafeMulInt64 returns the exact product of two signed 64-bit integers.
//
// Parameters:
//   - a: First signed int64 factor.
//   - b: Second signed int64 factor.
//
// Returns:
//   - product: a * b when the mathematical result is within [math.MinInt64, math.MaxInt64].
//
// Panics if the signed int64 product overflows or underflows.
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

// SafeMulDivInt64 returns the truncated quotient (a * b) / c.
//
// The product is formed in signed 256-bit arithmetic before division, so an
// intermediate product may exceed int64 while the final quotient must still fit.
//
// Parameters:
//   - a: First signed int64 factor.
//   - b: Second signed int64 factor.
//   - c: Non-zero signed int64 divisor.
//
// Returns:
//   - quotient: The signed integer quotient after dividing a * b by c.
//
// Panics if the 256-bit product overflows, c is zero, or the quotient is outside
// the representable int64 range.
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

// SafeAbsInt64 returns the non-negative absolute value of a.
//
// Parameters:
//   - a: Signed int64 value whose magnitude is requested.
//
// Returns:
//   - magnitude: |a| as int64.
//
// Panics when a is math.MinInt64 because its positive magnitude cannot be
// represented by int64.
func SafeAbsInt64(a int64) int64 {
	if a == math.MinInt64 {
		panic(errSafeMathOverflow)
	}
	if a < 0 {
		return -a
	}
	return a
}

// SafeAddUint64 returns the exact sum of two unsigned 64-bit integers.
//
// Parameters:
//   - a: First uint64 operand.
//   - b: Second uint64 operand.
//
// Returns:
//   - sum: a + b when the mathematical result is at most math.MaxUint64.
//
// Panics if the uint64 sum overflows.
func SafeAddUint64(a, b uint64) uint64 {
	if a > math.MaxUint64-b {
		panic("uint64 addition overflow")
	}
	return a + b
}

// SafeSubUint64 returns the exact difference of two unsigned 64-bit integers.
//
// Parameters:
//   - a: Unsigned uint64 minuend.
//   - b: Unsigned uint64 subtrahend; it must not exceed a.
//
// Returns:
//   - difference: a - b.
//
// Panics if b is greater than a and the subtraction would underflow uint64.
func SafeSubUint64(a, b uint64) uint64 {
	if a < b {
		panic("uint64 subtraction underflow")
	}
	return a - b
}

// SafeUint64ToInt64 converts a uint64 to a signed int64 without changing its value.
//
// Parameters:
//   - value: Unsigned value to convert; it must be no greater than 2^63 - 1.
//
// Returns:
//   - converted: value represented as int64.
//
// Panics when value exceeds math.MaxInt64.
func SafeUint64ToInt64(value uint64) int64 {
	if value > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf(
			"amount(%d) overflows int64 range (max: %s)",
			value, maxInt64Decimal,
		))
	}
	return int64(value)
}

// SafeConvertToInt64 converts a non-negative 256-bit integer to int64.
//
// Parameters:
//   - value: Unsigned 256-bit value to convert; nil is invalid.
//
// Returns:
//   - converted: value represented as int64 when it is at most math.MaxInt64.
//
// Panics when value is nil or outside the int64 range.
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

// SafeConvertToInt128 converts a non-negative 256-bit integer to signed int128.
//
// Parameters:
//   - value: Unsigned 256-bit value to convert; nil is invalid.
//
// Returns:
//   - converted: A new *i256.Int representing value when it is at most 2^127 - 1.
//
// Panics when value is nil or exceeds the largest positive signed int128 value.
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
