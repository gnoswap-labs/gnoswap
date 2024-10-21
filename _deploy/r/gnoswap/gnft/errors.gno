package gnft

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission = errors.New("[GNOSWAP-GNFT-001] no permission")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
