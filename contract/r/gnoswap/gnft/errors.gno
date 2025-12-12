package gnft

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errCannotSetURI = errors.New("[GNOSWAP-GNFT-001] cannot set URI")

	errInvalidAddress = errors.New("[GNOSWAP-GNFT-002] invalid addresss")

	// Transfer errors
	errNotOwnerOrApproved = errors.New("[GNOSWAP-GNFT-003] caller is not token owner or approved")
	errTokenNotExists     = errors.New("[GNOSWAP-GNFT-004] token does not exist")
	errTransferToSelf     = errors.New("[GNOSWAP-GNFT-005] cannot transfer to self")

	errInvalidTokenParams      = errors.New("[GNOSWAP-GNFT-006] invalid token parameters")
	errInvalidTokenParamsRange = errors.New("[GNOSWAP-GNFT-007] token parameters out of range")
	errInvalidColorFormat      = errors.New("[GNOSWAP-GNFT-008] invalid color format")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
