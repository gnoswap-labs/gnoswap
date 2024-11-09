package emission

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission          = errors.New("[GNOSWAP-EMISSION-001] caller has no permission")
	errInvalidEmissionTarget = errors.New("[GNOSWAP-EMISSION-002] invalid emission target")
	errInvalidEmissionPct    = errors.New("[GNOSWAP-EMISSION-003] invalid emission percentage")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
