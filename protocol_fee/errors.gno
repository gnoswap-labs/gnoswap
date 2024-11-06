package protocol_fee

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-PROTOCOL_FEE-001] no permission")
	errNotRegistered     = errors.New("[GNOSWAP-PROTOCOL_FEE-002] not registered")
	errAlreadyRegistered = errors.New("[GNOSWAP-PROTOCOL_FEE-003] already registered")
	errLocked            = errors.New("[GNOSWAP-PROTOCOL_FEE-004] can't transfer token while locked")
	errInvalidInput      = errors.New("[GNOSWAP-PROTOCOL_FEE-005] invalid input")
	errInvalidPct        = errors.New("[GNOSWAP-PROTOCOL_FEE-006] invalid percentage")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
