package common

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission   = errors.New("[GNOSWAP-COMMON-001] caller has no permission")
	errHalted         = errors.New("[GNOSWAP-COMMON-002] halted")
	errOutOfRange     = errors.New("[GNOSWAP-COMMON-003] value out of range")
	errNotRegistered  = errors.New("[GNOSWAP-COMMON-004] token is not registered")
	errInvalidAddr    = errors.New("[GNOSWAP-COMMON-005] invalid address")
	errOverflow       = errors.New("[GNOSWAP-COMMON-006] overflow")
	errInvalidTokenId = errors.New("[GNOSWAP-COMMON-007] invalid tokenId")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
