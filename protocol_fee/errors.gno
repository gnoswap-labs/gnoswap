package protocol_fee

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-PROTOCOL_FEE-001] no permission")
	errNotRegistered     = errors.New("[GNOSWAP-PROTOCOL_FEE-002] not registered")
	errAlreadyRegistered = errors.New("[GNOSWAP-PROTOCOL_FEE-003] already registered")
	errInvalidInput      = errors.New("[GNOSWAP-PROTOCOL_FEE-004] invalid input")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
