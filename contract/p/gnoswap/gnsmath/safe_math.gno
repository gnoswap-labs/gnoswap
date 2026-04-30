package gnsmath

import (
	"math"
	"strconv"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// SafeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow.
func SafeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}

	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}

	return a + b
}

// SafeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow.
func SafeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}

	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}

	return a - b
}

// SafeMulInt64 performs safe multiplication of int64 values, panicking on overflow or underflow.
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

// SafeMulDivInt64 computes (a * b) / c safely using i256 for intermediate multiplication.
func SafeMulDivInt64(a, b, c int64) int64 {
	if c == 0 {
		panic("division by zero in SafeMulDivInt64")
	}

	if a == 0 || b == 0 {
		return 0
	}

	result, overflow := i256.Zero().MulOverflow(i256.NewInt(a), i256.NewInt(b))
	if overflow {
		panic("int64 multiplication overflow in SafeMulDivInt64")
	}

	result = i256.Zero().Div(result, i256.NewInt(c))
	if !result.IsInt64() {
		panic("int64 overflow in SafeMulDivInt64")
	}

	return result.Int64()
}

// SafeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
func SafeConvertToInt64(value *u256.Uint) int64 {
	if value == nil {
		panic("SafeConvertToInt64: value is nil")
	}
	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max: 9223372036854775807)",
			value.ToString(),
		))
	}
	return int64(res)
}

// SafeConvertToUint64 safely converts a *u256.Uint value to a uint64, ensuring no overflow.
func SafeConvertToUint64(value *u256.Uint) uint64 {
	if value == nil {
		panic("SafeConvertToUint64: value is nil")
	}
	res, overflow := value.Uint64WithOverflow()
	if overflow {
		panic(ufmt.Sprintf(
			"amount(%s) overflows uint64 range (max: 18446744073709551615)",
			value.ToString(),
		))
	}
	return res
}

// SafeConvertToInt128 safely converts a *u256.Uint value to an *i256.Int, ensuring it does not exceed the int128 range.
func SafeConvertToInt128(value *u256.Uint) *i256.Int {
	if value == nil {
		panic("SafeConvertToInt128: value is nil")
	}
	result := i256.FromUint256(value)
	maxInt128 := i256.MustFromDecimal("170141183460469231731687303715884105727")
	if result.Gt(maxInt128) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int128 range",
			value.ToString(),
		))
	}
	return result
}

// SafeParseInt64 parses a decimal string to int64, panicking on error.
func SafeParseInt64(value string) int64 {
	n, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}
	return n
}

// SafeUint64ToInt64 safely converts a uint64 value to int64, panicking on overflow.
func SafeUint64ToInt64(value uint64) int64 {
	if value > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf(
			"amount(%d) overflows int64 range (max: 9223372036854775807)",
			value,
		))
	}
	return int64(value)
}

// SafeAbsInt64 returns the absolute value of a, panicking if a == math.MinInt64.
func SafeAbsInt64(a int64) int64 {
	if a == math.MinInt64 {
		panic("int64 abs overflow")
	}
	if a < 0 {
		return -a
	}
	return a
}
