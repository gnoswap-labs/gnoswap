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
