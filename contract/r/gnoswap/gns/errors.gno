package gns

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidYear           = "[GNOSWAP-GNS-001] invalid year"
	errTooManyEmission       = "[GNOSWAP-GNS-002] too many emission reward"
	errInvalidEmissionAmount = "[GNOSWAP-GNS-003] invalid emission amount"
)

func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
