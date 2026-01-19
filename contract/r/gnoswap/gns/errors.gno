package gns

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidYear             = errors.New("[GNOSWAP-GNS-001] invalid year")
	errTooManyEmission         = errors.New("[GNOSWAP-GNS-002] too many emission reward")
	errInvalidAvgBlockTimeInMs = errors.New("[GNOSWAP-GNS-003] invalid avg block time in ms")
	errInvalidEmissionAmount   = errors.New("[GNOSWAP-GNS-004] invalid emission amount")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
