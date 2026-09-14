package common

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errNotHandleNativeCoin = "[GNOSWAP-COMMON-002] handle native coin is not allowed"
)

// newErrorWithDetail creates an error message with additional context in format "<original_error> || <detail>".
func newErrorWithDetail(message string, detail string) string {
	return ufmt.Errorf("%s || %s", message, detail).Error()
}
