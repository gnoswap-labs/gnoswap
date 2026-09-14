package common

import (
	"gno.land/p/nt/ufmt/v0"
)

const (
	errNotRegistered       = "[GNOSWAP-COMMON-001] token is not registered"
	errNotHandleNativeCoin = "[GNOSWAP-COMMON-002] handle native coin is not allowed"
	errInvalidTokenKey = "[GNOSWAP-COMMON-003] invalid token key"
)

func newErrorWithDetail(message string, detail string) string {
	return ufmt.Errorf("%s || %s", message, detail).Error()
}
