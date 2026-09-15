package gnft

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errCannotSetURI   = "[GNOSWAP-GNFT-001] cannot set URI"
	errInvalidAddress = "[GNOSWAP-GNFT-002] invalid address"

	// Transfer errors
	errNotOwnerOrApproved = "[GNOSWAP-GNFT-003] caller is not token owner or approved"
	errTokenNotExists     = "[GNOSWAP-GNFT-004] token does not exist"
	errTransferToSelf     = "[GNOSWAP-GNFT-005] cannot transfer to self"

	errInvalidTokenParams      = "[GNOSWAP-GNFT-006] invalid token parameters"
	errInvalidTokenParamsRange = "[GNOSWAP-GNFT-007] token parameters out of range"
	errInvalidColorFormat      = "[GNOSWAP-GNFT-008] invalid color format"
	errStakedTokenLocked       = "[GNOSWAP-GNFT-009] staked token is locked"
	errSpoofedRealm            = "[GNOSWAP-GNFT-010] rlm does not match the current crossing frame"
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
