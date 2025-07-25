package launchpad

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

// formatInt returns the string representation of the int64 value.
func formatInt(value int64) string {
	return strconv.FormatInt(value, 10)
}

// assertValidAmount panics if the amount is zero.
func assertValidAmount(amount int64) {
	if amount < minimumDepositAmount {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should greater than minimum deposit amount(%d)", amount, minimumDepositAmount),
		))
	}
	if (amount % minimumDepositAmount) != 0 {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) must be a multiple of 1_000_000", amount),
		))
	}
}

// parseProjectTierID parses a project tier ID into its project ID and duration.
//
// This function splits the project tier ID into its components and extracts
// the project ID and duration. It also validates the format of the ID.
//
// Parameters:
// - projectTierID (string): The ID of the project tier to parse.
//
// Returns:
// - string: The project ID {tokenPath}:{createdHeight}.
// - int64: The duration of the project tier (30, 90, 180).
//
// Panics:
// - If the project tier ID is not in the correct format.
// - If the duration is not a valid integer.
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
