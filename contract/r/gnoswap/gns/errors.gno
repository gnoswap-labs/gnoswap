package gns

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidYear                 = errors.New("[GNOSWAP-GNS-001] invalid year")
	errTooManyEmission             = errors.New("[GNOSWAP-GNS-002] too many emission reward")
	errEmissionChangeIsNilCallback = errors.New("[GNOSWAP-GNS-003] callback emission change is nil")
	errInvalidAvgBlockTimeInMs     = errors.New("[GNOSWAP-GNS-004] invalid avg block time in ms")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
