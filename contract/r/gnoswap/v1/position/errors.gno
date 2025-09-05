package position

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission          = errors.New("[GNOSWAP-POSITION-001] caller has no permission")
	errSlippage              = errors.New("[GNOSWAP-POSITION-002] slippage failed")
	errWrapUnwrap            = errors.New("[GNOSWAP-POSITION-003] wrap, unwrap failed")
	errZeroWrappedAmount     = errors.New("[GNOSWAP-POSITION-004] zero wrapped amount")
	errInvalidInput          = errors.New("[GNOSWAP-POSITION-005] invalid input data")
	errDataNotFound          = errors.New("[GNOSWAP-POSITION-006] requested data not found")
	errExpired               = errors.New("[GNOSWAP-POSITION-007] transaction expired")
	errWugnotMinimum         = errors.New("[GNOSWAP-POSITION-008] can not wrap less than minimum amount")
	errNotClear              = errors.New("[GNOSWAP-POSITION-009] position is not clear")
	errZeroLiquidity         = errors.New("[GNOSWAP-POSITION-010] zero liquidity")
	errPositionExist         = errors.New("[GNOSWAP-POSITION-011] position with same positionId already exists")
	errInvalidAddress        = errors.New("[GNOSWAP-POSITION-012] invalid address")
	errPositionDoesNotExist  = errors.New("[GNOSWAP-POSITION-013] position does not exist")
	errZeroUGNOT             = errors.New("[GNOSWAP-POSITION-014] No UGNOTs were sent")
	errInsufficientUGNOT     = errors.New("[GNOSWAP-POSITION-015] Insufficient UGNOT provided")
	errInvalidTokenPath      = errors.New("[GNOSWAP-POSITION-016] invalid token address")
	errInvalidLiquidityRatio = errors.New("[GNOSWAP-POSITION-017] invalid liquidity ratio")
	errUnderflow             = errors.New("[GNOSWAP-POSITION-018] underflow")
	errOverflow              = errors.New("[GNOSWAP-POSITION-019] overflow")
	errInvalidLiquidity      = errors.New("[GNOSWAP-POSITION-019] invalid liquidity")
)

// newErrorWithDetail appends additional context or details to an existing error message.
func newErrorWithDetail(err error, detail string) string {
	return ufmt.Errorf("%s || %s", err.Error(), detail).Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
