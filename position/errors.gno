package position

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission  = errors.New("[GNOSWAP-POSITION-001] caller has no permission")
	errSlippage      = errors.New("[GNOSWAP-POSITION-002] slippage failed")
	errWrapUnwrap    = errors.New("[GNOSWAP-POSITION-003] wrap, unwrap failed")
	errOutOfRange    = errors.New("[GNOSWAP-POSITION-004] out of range for numeric value")
	errInvalidInput  = errors.New("[GNOSWAP-POSITION-005] invalid input data")
	errDataNotFound  = errors.New("[GNOSWAP-POSITION-006] requested data not found")
	errExpired       = errors.New("[GNOSWAP-POSITION-007] transaction expired")
	errWugnotMinimum = errors.New("[GNOSWAP-POSITION-008] can not wrap less than minimum amount")
	errNotClear      = errors.New("[GNOSWAP-POSITION-009] position is not clear")
	errZeroLiquidity = errors.New("[GNOSWAP-POSITION-010] zero liquidity")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
