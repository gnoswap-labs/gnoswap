package gnft

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission  = errors.New("[GNOSWAP-GNFT-001] caller has no permission")
	errNotTokenOwner = errors.New("[GNOSWAP-GNFT-001] caller is not token owner")

	errCannotSetURI      = errors.New("[GNOSWAP-GNFT-002] cannot set URI")
	errTokenDoesNotExist = errors.New("[GNOSWAP-GNFT-002] cannot set URI || token does not exist")
	errTokenBurned       = errors.New("[GNOSWAP-GNFT-002] cannot set URI || token has been burned")

	errNoTokenForCaller = errors.New("[GNOSWAP-GNFT-003] no token for caller")
	errInvalidAddress   = errors.New("[GNOSWAP-GNFT-004] invalid addresss")
	errInvalidTokenID   = errors.New("[GNOSWAP-GNFT-005] invalid token ID")

	// Transfer errors
	errNotOwnerOrApproved = errors.New("[GNOSWAP-GNFT-006] caller is not token owner or approved")
	errTokenNotExists     = errors.New("[GNOSWAP-GNFT-007] token does not exist")
	errTransferToSelf     = errors.New("[GNOSWAP-GNFT-008] cannot transfer to self")
	errNotApprovedForAll  = errors.New("[GNOSWAP-GNFT-009] not approved for all tokens")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
