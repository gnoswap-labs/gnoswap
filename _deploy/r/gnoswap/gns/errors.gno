package gns

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission = errors.New("[GNOSWAP-GNS-001] caller has no permission")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
