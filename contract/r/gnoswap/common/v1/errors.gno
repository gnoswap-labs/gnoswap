package common

import (
	"gno.land/p/nt/ufmt/v0"
)

const (
	errNotRegistered = "[GNOSWAP-COMMON-001] token is not registered"
)

func newErrorWithDetail(message string, detail string) string {
	return ufmt.Errorf("%s || %s", message, detail).Error()
}
