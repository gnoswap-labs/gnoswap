package launchpad

import (
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

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

	projectID := ufmt.Sprintf("%s:%s", parts[0], parts[1])

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
	const INT64_MAX = 9223372036854775807
	const MAX_INT64 = "9223372036854775807"

	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(INT64_MAX) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max %s)",
			value.ToString(),
			MAX_INT64,
		))
	}
	return int64(res)
}
