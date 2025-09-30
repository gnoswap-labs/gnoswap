package emission

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errCallbackIsNil               = errors.New("[GNOSWAP-EMISSION-001] callback func is nil")
	errInvalidEmissionTarget       = errors.New("[GNOSWAP-EMISSION-002] invalid emission target")
	errInvalidEmissionPct          = errors.New("[GNOSWAP-EMISSION-003] invalid emission percentage")
	errDuplicateTarget             = errors.New("[GNOSWAP-EMISSION-004] duplicate emission target")
	errEmissionAddressNotFound     = errors.New("[GNOSWAP-EMISSION-005] emission address not found")
	errDistributionAddressNotFound = errors.New("[GNOSWAP-EMISSION-006] distribution address not found")
)

// makeErrorWithDetails creates a new error by combining a base error with additional details.
func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
