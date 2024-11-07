package router

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission       = errors.New("[GNOSWAP-ROUTER-001] no permission")
	errNotRegistered      = errors.New("[GNOSWAP-ROUTER-002] not registered")
	errAlreadyRegistered  = errors.New("[GNOSWAP-ROUTER-003] already registered")
	errLocked             = errors.New("[GNOSWAP-ROUTER-004] can't transfer token while locked")
	errInvalidInput       = errors.New("[GNOSWAP-ROUTER-005] invalid input")
	errInvalidPoolFeeTier = errors.New("[GNOSWAP-ROUTER-006] invalid pool fee tier")
	errInvalidSwapFee     = errors.New("[GNOSWAP-ROUTER-007] invalid swap fee")
	errInvalidSwapType    = errors.New("[GNOSWAP-ROUTER-008] invalid swap type")
	errInvalidPoolPath    = errors.New("[GNOSWAP-ROUTER-009] invalid pool path")
	errWrapUnwrap         = errors.New("[GNOSWAP-ROUTER-010] wrap/unwrap")
	errWugnotMinimum      = errors.New("[GNOSWAP-ROUTER-011] wugnot minimum")
	errSlippage           = errors.New("[GNOSWAP-ROUTER-012] slippage")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
