package common

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var (
	errNotRegistered       = errors.New("[GNOSWAP-COMMON-001] token is not registered")
	errNotHandleNativeCoin = errors.New("[GNOSWAP-COMMON-002] handle native coin is not allowed")
)

// newErrorWithDetail creates an error message with additional context in format "<original_error> || <detail>".
func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}
