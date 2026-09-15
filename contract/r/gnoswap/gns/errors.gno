package gns

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidYear           = "[GNOSWAP-GNS-001] invalid year"
	errTooManyEmission       = "[GNOSWAP-GNS-002] too many emission reward"
	errInvalidEmissionAmount = "[GNOSWAP-GNS-003] invalid emission amount"
)

// makeErrorWithDetails combines a base GNS error message with detail text.
//
// Parameters:
//   - message: base GNS error text identifying the failure category
//   - details: contextual text appended to the base message
//
// Returns:
//   - error: newly formatted error containing message, a separator, and details
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
