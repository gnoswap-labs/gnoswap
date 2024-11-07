package position

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission  = errors.New("[GNOSWAP-POSITION-001] no permission")
	errSlippage      = errors.New("[GNOSWAP-POSITION-002] slippage")
	errWrapUnwrap    = errors.New("[GNOSWAP-POSITION-003] wrap/unwrap")
	errOutOfRange    = errors.New("[GNOSWAP-POSITION-004] out of range")
	errInvalidInput  = errors.New("[GNOSWAP-POSITION-005] invalid input")
	errDataNotFound  = errors.New("[GNOSWAP-POSITION-006] data not found")
	errExpired       = errors.New("[GNOSWAP-POSITION-007] expired transaction")
	errWugnotMinimum = errors.New("[GNOSWAP-POSITION-008] wugnot minimum")
	errNotClear      = errors.New("[GNOSWAP-POSITION-009] not clear")
	errZeroLiquidity = errors.New("[GNOSWAP-POSITION-010] zero liquidity")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
