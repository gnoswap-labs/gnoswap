package protocol_fee

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-PROTOCOL_FEE-001] caller has no permission")
	errNotRegistered     = errors.New("[GNOSWAP-PROTOCOL_FEE-002] not registered token")
	errAlreadyRegistered = errors.New("[GNOSWAP-PROTOCOL_FEE-003] already registered token")
	errLocked            = errors.New("[GNOSWAP-PROTOCOL_FEE-004] can't transfer token while locked")
	errInvalidInput      = errors.New("[GNOSWAP-PROTOCOL_FEE-005] invalid input data")
	errInvalidPct        = errors.New("[GNOSWAP-PROTOCOL_FEE-006] invalid percentage")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
