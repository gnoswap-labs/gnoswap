package common

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errOutOfRange          = errors.New("[GNOSWAP-COMMON-001] value out of range")
	errNotRegistered       = errors.New("[GNOSWAP-COMMON-002] token is not registered")
	errInvalidInput        = errors.New("[GNOSWAP-COMMON-003] invalid input data")
	errOverflow            = errors.New("[GNOSWAP-COMMON-004] overflow")
	errIdenticalTicks      = errors.New("[GNOSWAP-COMMON-005] identical ticks")
	errNotHandleNativeCoin = errors.New("[GNOSWAP-COMMON-006] handle native coin is not allowed")
)

// newErrorWithDetail creates an error message with additional context in format "<original_error> || <detail>".
func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}
