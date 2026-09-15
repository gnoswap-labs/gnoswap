package emission

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidEmissionTarget       = "[GNOSWAP-EMISSION-001] invalid emission target"
	errInvalidEmissionPct          = "[GNOSWAP-EMISSION-002] invalid emission percentage"
	errDuplicateTarget             = "[GNOSWAP-EMISSION-003] duplicate emission target"
	errDistributionAddressNotFound = "[GNOSWAP-EMISSION-004] distribution address not found"
	errInvalidEmissionStart        = "[GNOSWAP-EMISSION-005] invalid emission start"
)

// makeErrorWithDetails combines a base emission error message with detail text.
//
// Parameters:
//   - message: base emission error text identifying the failure category
//   - detail: contextual text appended to the base message
//
// Returns:
//   - error: newly formatted error containing message, a separator, and detail
func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
