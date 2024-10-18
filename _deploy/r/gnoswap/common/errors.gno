package common

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission = errors.New("[GNOSWAP-COMMON-001] no permission")
	errHalted       = errors.New("[GNOSWAP-COMMON-002] halted")
	errOutOfRange   = errors.New("[GNOSWAP-COMMON-003] value out of range")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
