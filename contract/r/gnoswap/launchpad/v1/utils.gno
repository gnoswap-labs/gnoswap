package v1

import (
	"math"
	"strconv"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	MAX_INT64 = math.MaxInt64
	MIN_INT64 = math.MinInt64
)

func buildConditionEventAttrs(conditionTokens string, conditionAmounts string) []string {
	if conditionTokens == "" {
		return []string{}
	}

	tokenPaths := strings.Split(conditionTokens, stringSplitterPad)
	amounts := strings.Split(conditionAmounts, stringSplitterPad)
	eventAttrs := make([]string, 0, len(tokenPaths)*2)

	for index, tokenPath := range tokenPaths {
		eventAttrs = append(eventAttrs, ufmt.Sprintf("conditionsTokens[%d]", index))
		eventAttrs = append(eventAttrs, tokenPath+stringSplitterPad+amounts[index])
	}

	return eventAttrs
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
