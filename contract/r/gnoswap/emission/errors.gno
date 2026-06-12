package emission

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidEmissionTarget       = "[GNOSWAP-EMISSION-001] invalid emission target"
	errInvalidEmissionPct          = "[GNOSWAP-EMISSION-002] invalid emission percentage"
	errDuplicateTarget             = "[GNOSWAP-EMISSION-003] duplicate emission target"
	errDistributionAddressNotFound = "[GNOSWAP-EMISSION-004] distribution address not found"
)

// makeErrorWithDetails creates a new error by combining a base error with additional details.
func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
