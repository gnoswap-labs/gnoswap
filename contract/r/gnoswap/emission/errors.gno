package emission

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidEmissionTarget       = errors.New("[GNOSWAP-EMISSION-001] invalid emission target")
	errInvalidEmissionPct          = errors.New("[GNOSWAP-EMISSION-002] invalid emission percentage")
	errDuplicateTarget             = errors.New("[GNOSWAP-EMISSION-003] duplicate emission target")
	errDistributionAddressNotFound = errors.New("[GNOSWAP-EMISSION-004] distribution address not found")
)

// makeErrorWithDetails creates a new error by combining a base error with additional details.
func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
