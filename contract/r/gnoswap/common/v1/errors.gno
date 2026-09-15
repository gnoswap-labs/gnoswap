package common

import (
	"gno.land/p/nt/ufmt/v0"
)

const (
	errNotRegistered       = "[GNOSWAP-COMMON-001] token is not registered"
	errNotHandleNativeCoin = "[GNOSWAP-COMMON-002] handle native coin is not allowed"
	errInvalidTokenKey     = "[GNOSWAP-COMMON-003] invalid token key"
)

// newErrorWithDetail formats a base error message together with contextual detail.
//
// Parameters:
//   - message: base error message describing the failure.
//   - detail: additional context appended to the base message.
//
// Returns:
//   - formattedMessage: error text containing message and detail separated by " || ".
func newErrorWithDetail(message string, detail string) string {
	return ufmt.Errorf("%s || %s", message, detail).Error()
}
