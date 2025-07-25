package emission

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errCallbackIsNil         = errors.New("[GNOSWAP-EMISSION-001] callback func is nil")
	errInvalidEmissionTarget = errors.New("[GNOSWAP-EMISSION-002] invalid emission target")
	errInvalidEmissionPct    = errors.New("[GNOSWAP-EMISSION-003] invalid emission percentage")
	errDuplicateTarget       = errors.New("[GNOSWAP-EMISSION-004] duplicate emission target")
)

func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
