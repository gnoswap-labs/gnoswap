package common

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-COMMON-001] caller has no permission")
	errHalted            = errors.New("[GNOSWAP-COMMON-002] halted")
	errOutOfRange        = errors.New("[GNOSWAP-COMMON-003] value out of range")
	errNotRegistered     = errors.New("[GNOSWAP-COMMON-004] token is not registered")
	errInvalidAddr       = errors.New("[GNOSWAP-COMMON-005] invalid address")
	errOverflow          = errors.New("[GNOSWAP-COMMON-006] overflow")
	errInvalidPositionId = errors.New("[GNOSWAP-COMMON-007] invalid positionId")
	errInvalidInput      = errors.New("[GNOSWAP-COMMON-008] invalid input data")
	errOverFlow          = errors.New("[GNOSWAP-COMMON-009] overflow")
	errIdenticalTicks    = errors.New("[GNOSWAP-COMMON-010] identical ticks")
)

// newErrorWithDetail creates an error message with additional context in format "<original_error> || <detail>".
func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}
