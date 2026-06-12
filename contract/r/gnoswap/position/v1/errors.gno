package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errNoPermission         = "[GNOSWAP-POSITION-001] caller has no permission"
	errSlippage             = "[GNOSWAP-POSITION-002] slippage failed"
	errInvalidTokenPath     = "[GNOSWAP-POSITION-003] invalid token address"
	errInvalidInput         = "[GNOSWAP-POSITION-004] invalid input data"
	errDataNotFound         = "[GNOSWAP-POSITION-005] requested data not found"
	errExpired              = "[GNOSWAP-POSITION-006] transaction expired"
	errInvalidLiquidity     = "[GNOSWAP-POSITION-007] invalid liquidity"
	errNotClear             = "[GNOSWAP-POSITION-008] position is not clear"
	errZeroLiquidity        = "[GNOSWAP-POSITION-009] zero liquidity"
	errPositionExist        = "[GNOSWAP-POSITION-010] position with same positionId already exists"
	errInvalidAddress       = "[GNOSWAP-POSITION-011] invalid address"
	errPositionDoesNotExist = "[GNOSWAP-POSITION-012] position does not exist"
	errUnderflow            = "[GNOSWAP-POSITION-013] underflow"
	errOverflow             = "[GNOSWAP-POSITION-014] overflow"
	errCannotMintToStaker   = "[GNOSWAP-POSITION-015] cannot mint to staker"
	errSpoofedRealm         = "[GNOSWAP-POSITION-016] rlm does not match the current crossing frame"
)

// newErrorWithDetail appends additional context or details to an existing error message.
func newErrorWithDetail(message string, detail string) string {
	return ufmt.Errorf("%s || %s", message, detail).Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
