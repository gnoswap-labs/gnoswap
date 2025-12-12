package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission         = errors.New("[GNOSWAP-POSITION-001] caller has no permission")
	errSlippage             = errors.New("[GNOSWAP-POSITION-002] slippage failed")
	errWrapUnwrap           = errors.New("[GNOSWAP-POSITION-003] wrap, unwrap failed")
	errInvalidInput         = errors.New("[GNOSWAP-POSITION-004] invalid input data")
	errDataNotFound         = errors.New("[GNOSWAP-POSITION-005] requested data not found")
	errExpired              = errors.New("[GNOSWAP-POSITION-006] transaction expired")
	errWugnotMinimum        = errors.New("[GNOSWAP-POSITION-007] can not wrap less than minimum amount")
	errNotClear             = errors.New("[GNOSWAP-POSITION-008] position is not clear")
	errZeroLiquidity        = errors.New("[GNOSWAP-POSITION-009] zero liquidity")
	errPositionExist        = errors.New("[GNOSWAP-POSITION-010] position with same positionId already exists")
	errInvalidAddress       = errors.New("[GNOSWAP-POSITION-011] invalid address")
	errPositionDoesNotExist = errors.New("[GNOSWAP-POSITION-012] position does not exist")
	errZeroUGNOT            = errors.New("[GNOSWAP-POSITION-013] No UGNOTs were sent")
	errInsufficientUGNOT    = errors.New("[GNOSWAP-POSITION-014] Insufficient UGNOT provided")
	errInvalidTokenPath     = errors.New("[GNOSWAP-POSITION-015] invalid token address")
	errUnderflow            = errors.New("[GNOSWAP-POSITION-016] underflow")
	errOverflow             = errors.New("[GNOSWAP-POSITION-017] overflow")
	errInvalidLiquidity     = errors.New("[GNOSWAP-POSITION-018] invalid liquidity")
)

// newErrorWithDetail appends additional context or details to an existing error message.
func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
