package gns

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var (
	errInvalidYear           = errors.New("[GNOSWAP-GNS-001] invalid year")
	errTooManyEmission       = errors.New("[GNOSWAP-GNS-002] too many emission reward")
	errInvalidEmissionAmount = errors.New("[GNOSWAP-GNS-003] invalid emission amount")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
