package launchpad

import (
	"strings"

	"gno.land/p/demo/ufmt"
)

// splitProjectIdAndTier extracts the project ID and tier from a given tier ID.
//
// This function splits the provided `tierId` into three parts using the `:` separator and
// returns the first two parts as the project ID and the third part as the tier.
//
// Parameters:
// - tierId (string): The tier ID in the format "{projectId}:{tier}".
//
// Returns:
// - string: The project ID derived from the first two parts of the `tierId`.
// - string: The tier derived from the third part of the `tierId`.
// - error: If the tier ID is invalid, an error is returned.
func SplitProjectIdAndTier(tierId string) (string, string, error) {
	res := strings.Split(tierId, ":")
	if len(res) != 3 {
		return "", "", ufmt.Errorf("invalid tierId: %s", tierId)
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1]), res[2], nil
}

// ParseTierDuration converts a tier type string to its corresponding uint64 value.
//
// This function maps tier strings ("30", "90", "180") to predefined constants (`TIER30`, `TIER90`, `TIER180`).
// If the input string is invalid, the function panics.
//
// Parameters:
// - tierType (string): The tier type as a string.
//
// Returns:
// - uint64: The corresponding uint64 constant for the tier type.
// - error: If the tierType is invalid, an error is returned.
func ParseTierDuration(tierType string) (uint64, error) {
	switch tierType {
	case "30":
		return TIER30
	case "90":
		return TIER90
	case "180":
		return TIER180
	default:
		return 0, ufmt.Errorf("invalid tierType: %s", tierType)
	}
}

// FromTierTypeStr converts a tier type string ("30", "90", "180") to its corresponding uint64 tier value.
// Panics if the tier type is invalid.
func FromTierType(tierType string) (uint64, error) {
	switch tierType {
	case "30":
		return TIER30
	case "90":
		return TIER90
	case "180":
		return TIER180
	default:
		return 0, ufmt.Errorf("invalid tierType: %s", tierType)
	}
}
