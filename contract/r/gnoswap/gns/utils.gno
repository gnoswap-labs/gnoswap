package gns

import (
	"math"
	"strconv"

	"gno.land/p/nt/ufmt"
)

// validBlockTime validates that block time is within acceptable range.
// Returns error if block time is <= 0 or >= 1e9.
func validBlockTime(blockTime int64) error {
	if blockTime <= 0 || blockTime >= 1e9 {
		return errInvalidAvgBlockTimeInMs
	}

	return nil
}

// validYear validates that year is within halving period range (1-12).
// Returns error if year is outside the valid range.
func validYear(year int64) error {
	if year < HALVING_START_YEAR || year > HALVING_END_YEAR {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	return nil
}

// validEmissionAmount validates that the emission amount does not exceed maximum.
// Returns error if minting the amount would exceed MAX_EMISSION_AMOUNT.
func validEmissionAmount(amount int64) error {
	if amount < 0 {
		return makeErrorWithDetails(errInvalidEmissionAmount, ufmt.Sprintf("emission amount cannot be negative: %d", amount))
	}

	if safeAddInt64(amount, MintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		return makeErrorWithDetails(errTooManyEmission, ufmt.Sprintf("too many emission amount: %d", amount))
	}

	return nil
}

// i64Min returns the smaller of two int64 values.
func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

// formatUint formats unsigned integer types to string.
// Supports uint8, uint32, and uint64. Panics for unsupported types.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatInt formats signed integer types to string.
// Supports int32, int64, and int. Panics for unsupported types.
func formatInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// safeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow
func safeAddInt64(a, b int64) int64 {
	if a > 0 && b > math.MaxInt64-a {
		panic("int64 addition overflow")
	}
	if a < 0 && b < math.MinInt64-a {
		panic("int64 addition underflow")
	}
	return a + b
}

// safeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow
func safeSubInt64(a, b int64) int64 {
	if b > 0 && a < math.MinInt64+b {
		panic("int64 subtraction underflow")
	}
	if b < 0 && a > math.MaxInt64+b {
		panic("int64 subtraction overflow")
	}
	return a - b
}

// safeMulInt64 performs safe multiplication of int64 values, panicking on overflow or underflow
func safeMulInt64(a, b int64) int64 {
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
