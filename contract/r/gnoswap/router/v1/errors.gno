package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errSlippage               = errors.New("[GNOSWAP-ROUTER-001] slippage check failed")
	errInvalidRoutesAndQuotes = errors.New("[GNOSWAP-ROUTER-002] invalid routes and quotes")
	errExpired                = errors.New("[GNOSWAP-ROUTER-003] transaction expired")
	errInvalidInput           = errors.New("[GNOSWAP-ROUTER-004] invalid input data")
	errInvalidPoolFeeTier     = errors.New("[GNOSWAP-ROUTER-005] invalid pool fee tier")
	errInvalidSwapFee         = errors.New("[GNOSWAP-ROUTER-006] invalid swap fee")
	errInvalidSwapType        = errors.New("[GNOSWAP-ROUTER-007] invalid swap type")
	errInvalidPoolPath        = errors.New("[GNOSWAP-ROUTER-008] invalid pool path")
	errWugnotMinimum          = errors.New("[GNOSWAP-ROUTER-009] cannot wrap less than minimum amount")
	errHopsOutOfRange         = errors.New("[GNOSWAP-ROUTER-010] number of hops must be 1~3")
	errSameTokenSwap          = errors.New("[GNOSWAP-ROUTER-011] cannot swap same token")
	errOverflow               = errors.New("[GNOSWAP-ROUTER-012] overflow")
	errInvalidRoutePath       = errors.New("[GNOSWAP-ROUTER-013] invalid route path")
	errInvalidRouteFirstToken = errors.New("[GNOSWAP-ROUTER-014] invalid route first token")
	errInvalidRouteLastToken  = errors.New("[GNOSWAP-ROUTER-015] invalid route last token")
	errInvalidSwapAmount      = errors.New("[GNOSWAP-ROUTER-016] invalid swap amount")
	errUnAuthorizedCaller     = errors.New("[GNOSWAP-ROUTER-017] unauthorized caller")
)

// addDetailToError adds detail to an error message.
func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
