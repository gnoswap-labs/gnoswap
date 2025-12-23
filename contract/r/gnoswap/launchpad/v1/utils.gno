package v1

import (
	"math"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

const(
	MAX_INT64 = math.MaxInt64
	MIN_INT64 = math.MinInt64
)

func formatBool(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

// formatInt returns the string representation of the int64 value.
func formatInt(value int64) string {
	return strconv.FormatInt(value, 10)
}

// parseProjectTierID parses a project tier ID into its project ID and duration.
// Returns the project ID {tokenPath}:{createdHeight} and the duration of the project tier (30, 90, 180).
func parseProjectTierID(projectTierID string) (string, int64) {
	parts := strings.Split(projectTierID, ":")
	if len(parts) != 3 {
		panic(makeErrorWithDetails(
			errInvalidData,
			ufmt.Sprintf("(%s)", projectTierID),
		))
	}

	projectID := parts[0] + ":" + parts[1]

	tierDuration, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidData,
			ufmt.Sprintf("(%s)", projectTierID),
		))
	}

	// Validate tier duration
	if tierDuration != projectTier30 && tierDuration != projectTier90 && tierDuration != projectTier180 {
		panic(makeErrorWithDetails(
			errInvalidTier,
			ufmt.Sprintf("pool type(%d) is not available", tierDuration),
		))
	}

	return projectID, tierDuration
}

// safeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
//
// This function attempts to convert the given *u256.Uint value to an int64. If the value exceeds
// the maximum allowable range for int64 (`2^63 - 1`), it triggers a panic with a descriptive error message.
//
// Parameters:
// - value (*u256.Uint): The unsigned 256-bit integer to be converted.
//
// Returns:
// - int64: The converted value if it falls within the int64 range.
//
// Panics:
//   - If the `value` exceeds the range of int64, the function will panic with an error indicating
//     the overflow and the original value.
func safeConvertToInt64(value *u256.Uint) int64 {
	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(MAX_INT64) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max 9223372036854775807)",
			value.ToString(),
		))
	}
	return int64(res)
}

// safeAddInt64 performs safe addition of int64 values, panicking on overflow or underflow
func safeAddInt64(a, b int64) int64 {
	if a > 0 && b > MAX_INT64-a {
		panic("int64 addition overflow")
	}

	if a < 0 && b < MAX_INT64-a {
		panic("int64 addition underflow")
	}

	return a + b
}

// safeSubInt64 performs safe subtraction of int64 values, panicking on overflow or underflow
func safeSubInt64(a, b int64) int64 {
	if b > 0 && a < MIN_INT64+b {
		panic("int64 subtraction underflow")
	}

	if b < 0 && a > MIN_INT64+b {
		panic("int64 subtraction overflow")
	}

	return a - b
}
