package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidPct    = errors.New("[GNOSWAP-PROTOCOL_FEE-001] invalid percentage")
	errInvalidAmount = errors.New("[GNOSWAP-PROTOCOL_FEE-002] invalid amount")
)

// makeErrorWithDetail creates an error with additional context.
func makeErrorWithDetail(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
