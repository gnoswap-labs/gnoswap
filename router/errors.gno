package router

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-ROUTER-001] no permission")
	errNotRegistered     = errors.New("[GNOSWAP-ROUTER-002] not registered")
	errAlreadyRegistered = errors.New("[GNOSWAP-ROUTER-003] already registered")
	errInvalidInput      = errors.New("[GNOSWAP-ROUTER-004] invalid input")
	errWrapUnwrap        = errors.New("[GNOSWAP-ROUTER-005] wrap/unwrap")
	errSlippage          = errors.New("[GNOSWAP-ROUTER-006] slippage")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
