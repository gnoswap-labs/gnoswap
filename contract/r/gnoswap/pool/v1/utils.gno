package v1

import (
	"strconv"
	"strings"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// safeConvertToUint64 safely converts a *u256.Uint value to a uint64, ensuring no overflow.
// This function attempts to convert the given *u256.Uint value to a uint64.
// If the value exceeds the maximum allowable range for uint64 (2^64 - 1), it panics.
func safeConvertToUint64(value *u256.Uint) uint64 {
	res, overflow := value.Uint64WithOverflow()
	if overflow {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows uint64 range (max %s)",
			errOutOfRange,
			value.ToString(),
			MAX_UINT64,
		))
	}
	return res
}

// safeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
// This function attempts to convert the given *u256.Uint value to an int64.
// If the value exceeds the maximum allowable range for int64 (2^63 - 1), it panics.
func safeConvertToInt64(value *u256.Uint) int64 {
	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(INT64_MAX) {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows int64 range (max %s)",
			errOutOfRange,
			value.ToString(),
			MAX_INT64,
		))
	}
	return int64(res)
}

// safeConvertToInt128 safely converts a *u256.Uint value to an *i256.Int, ensuring it does not exceed the int128 range.
// This function converts an unsigned 256-bit integer to a signed 256-bit integer.
// If the value exceeds the maximum allowable int128 range (2^127 - 1), it panics.
func safeConvertToInt128(value *u256.Uint) *i256.Int {
	liquidityDelta := i256.FromUint256(value)
	if liquidityDelta.Gt(i256.MustFromDecimal(MAX_INT128)) {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows int128 range",
			errOverFlow, value.ToString()))
	}
	return liquidityDelta
}

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
		panic(newErrorWithDetail(
			errInvalidInput,
			"value is nil",
		))
	}

	if value.Gt(u256.MustFromDecimal(MAX_UINT128)) {
		mask := u256.Zero().Lsh(u256.One(), Q128_RESOLUTION)
		mask = u256.Zero().Sub(mask, u256.One())
		return u256.Zero().And(value, mask)
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

// checkTransferError checks transfer error.
func checkTransferError(err error) {
	if err != nil {
		panic(newErrorWithDetail(
			errTransferFailed,
			err.Error(),
		))
	}
}

// checkOverFlowInt128 checks if the value overflows the int128 range.
func checkOverFlowInt128(value *i256.Int) {
	if value.Gt(i256.MustFromDecimal(MAX_INT128)) {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows int128 range",
			errOverFlow, value.ToString()))
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

// validateSqrtPriceX96 validates that the given sqrtPriceX96 is within valid range
func validateSqrtPriceX96(sqrtPriceX96 *u256.Uint) error {
	if sqrtPriceX96.Lt(minSqrtRatio) || sqrtPriceX96.Gt(maxSqrtRatio) {
		return makeErrorWithDetails(
			errOutOfRange,
			ufmt.Sprintf("sqrtPriceX96(%s) is out of range", sqrtPriceX96.ToString()),
		)
	}
	return nil
}

func isValidFeeTier(feeTier uint32) bool {
	switch feeTier {
	case FeeTier100, FeeTier500, FeeTier3000, FeeTier10000:
		return true
	}

	return false
}

// MakePoolPath generates a unique pool path string based on the token paths and fee tier.
func MakePoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

// validateTicks validates the tick range for a liquidity position.
//
// This function performs three essential checks to ensure the provided
// tick values are valid before creating or modifying a liquidity position.
func validateTicks(tickLower, tickUpper int32) error {
	if tickLower >= tickUpper {
		return makeErrorWithDetails(
			errInvalidTickRange,
			ufmt.Sprintf("tickLower(%d), tickUpper(%d)", tickLower, tickUpper),
		)
	}

	if tickLower < MIN_TICK {
		return makeErrorWithDetails(
			errTickLowerInvalid,
			ufmt.Sprintf("tickLower(%d) < MIN_TICK(%d)", tickLower, MIN_TICK),
		)
	}

	if tickUpper > MAX_TICK {
		return makeErrorWithDetails(
			errTickUpperInvalid,
			ufmt.Sprintf("tickUpper(%d) > MAX_TICK(%d)", tickUpper, MAX_TICK),
		)
	}

	return nil
}
