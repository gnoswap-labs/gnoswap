package v1

import (
	"strconv"
	"strings"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"
	pl "gno.land/r/gnoswap/pool"
)

const (
	MAX_UINT64  string = "18446744073709551615"
	MAX_INT64   string = "9223372036854775807"
	MAX_INT128  string = "170141183460469231731687303715884105727"
	MAX_UINT128 string = "340282366920938463463374607431768211455"
	MAX_INT256  string = "57896044618658097711785492504343953926634992332820282019728792003956564819967"

	INT64_MIN int64 = -9223372036854775808
	INT64_MAX int64 = 9223372036854775807

	Q96_RESOLUTION  uint = 96
	Q128_RESOLUTION uint = 128

	Q64  string = "18446744073709551616"                    // 2 ** 64
	Q96  string = "79228162514264337593543950336"           // 2 ** 96
	Q128 string = "340282366920938463463374607431768211456" // 2 ** 128
)

var (
	maxInt128FromDecimal  = i256.MustFromDecimal(MAX_INT128)
	maxUint128FromDecimal = u256.MustFromDecimal(MAX_UINT128)
	q128FromDecimal       = u256.MustFromDecimal(Q128)
)

var uint128Mask = func() *u256.Uint {
	m := u256.Zero().Lsh(u256.One(), Q128_RESOLUTION)
	return m.Sub(m, u256.One())
}()

// toUint128 ensures a *u256.Uint value fits within the uint128 range.
//
// This function validates that the given `value` is properly initialized and checks whether
// it exceeds the maximum value of uint128. If the value exceeds the uint128 range,
// it applies a masking operation to truncate the value to fit within the uint128 limit.
//
// Parameters:
//   - value: *u256.Uint, the value to be checked and possibly truncated.
//
// Returns:
//   - *u256.Uint: A value guaranteed to fit within the uint128 range.
//
// Notes:
//   - The function first checks if the value is not nil to avoid potential runtime errors.
//   - The mask ensures that only the lower 128 bits of the value are retained.
//   - If the input value is already within the uint128 range, it is returned unchanged.
//   - If masking is required, a new instance is returned without modifying the input.
//   - MAX_UINT128 is a constant representing `2^128 - 1`.
func toUint128(value *u256.Uint) *u256.Uint {
	if value == nil {
		panic(newErrorWithDetail(errInvalidInput, "value is nil"))
	}

	if value.Gt(maxUint128FromDecimal) {
		return u256.Zero().And(value, uint128Mask)
	}
	return value
}

// u256Min returns the smaller of two *u256.Uint values.
//
// This function compares two unsigned 256-bit integers and returns the smaller of the two.
// If `num1` is less than `num2`, it returns `num1`; otherwise, it returns `num2`.
//
// Parameters:
// - num1 (*u256.Uint): The first unsigned 256-bit integer.
// - num2 (*u256.Uint): The second unsigned 256-bit integer.
//
// Returns:
// - *u256.Uint: The smaller of `num1` and `num2`.
//
// Notes:
//   - This function uses the `Lt` (less than) method of `*u256.Uint` to perform the comparison.
//   - The function assumes both input values are non-nil. If nil inputs are possible in the usage context,
//     additional validation may be needed.
//
// Example:
// smaller := u256Min(u256.MustFromDecimal("10"), u256.MustFromDecimal("20")) // Returns 10
// smaller := u256Min(u256.MustFromDecimal("30"), u256.MustFromDecimal("20")) // Returns 20
func u256Min(num1, num2 *u256.Uint) *u256.Uint {
	if num1.Lt(num2) {
		return num1
	}
	return num2
}

// checkOverFlowInt128 checks if the value overflows the int128 range.
func checkOverFlowInt128(value *i256.Int) {
	if value.Gt(maxInt128FromDecimal) {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows int128 range",
			errOverflow, value.ToString()))
	}
}

// checkTickSpacing checks if the tick is divisible by the tickSpacing.
func checkTickSpacing(tick, tickSpacing int32) {
	if tick%tickSpacing != 0 {
		panic(newErrorWithDetail(
			errInvalidTickAndTickSpacing,
			ufmt.Sprintf("tick(%d) MOD tickSpacing(%d) != 0(%d)", tick, tickSpacing, tick%tickSpacing),
		))
	}
}

// formatUint converts various unsigned integer types to string representation.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint16:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatInt converts various signed integer types to string representation.
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

// formatBool converts a boolean value to string representation.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

// ticksToString converts tick indices within a range to their string representation,
// including detailed tick information from the pool's tick storage.
func ticksToString(pool *pl.Pool, startTick, endTick int32) string {
	minTick, maxTick := startTick, endTick

	if minTick > maxTick {
		minTick, maxTick = maxTick, minTick
	}

	tickInfoStrings := make([]string, 0)

	pool.IterateTicks(minTick, maxTick, func(tick int32, tickInfo pl.TickInfo) bool {
		tickEventInfo := NewTickEventInfo(tick, tickInfo)
		tickInfoStrings = append(tickInfoStrings, tickEventInfo.ToString())

		return false
	})

	if len(tickInfoStrings) == 0 {
		return "[]"
	}

	return "[" + strings.Join(tickInfoStrings, ",") + "]"
}
