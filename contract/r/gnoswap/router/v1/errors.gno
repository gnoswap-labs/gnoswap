package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errSlippage               = "[GNOSWAP-ROUTER-001] slippage check failed"
	errInvalidRoutesAndQuotes = "[GNOSWAP-ROUTER-002] invalid routes and quotes"
	errExpired                = "[GNOSWAP-ROUTER-003] transaction expired"
	errInvalidInput           = "[GNOSWAP-ROUTER-004] invalid input data"
	errInvalidPoolFeeTier     = "[GNOSWAP-ROUTER-005] invalid pool fee tier"
	errInvalidSwapFee         = "[GNOSWAP-ROUTER-006] invalid swap fee"
	errInvalidSwapType        = "[GNOSWAP-ROUTER-007] invalid swap type"
	errInvalidPoolPath        = "[GNOSWAP-ROUTER-008] invalid pool path"
	errUnAuthorizedCaller     = "[GNOSWAP-ROUTER-009] unauthorized caller"
	errHopsOutOfRange         = "[GNOSWAP-ROUTER-010] number of hops must be 1~3"
	errSameTokenSwap          = "[GNOSWAP-ROUTER-011] cannot swap same token"
	errOverflow               = "[GNOSWAP-ROUTER-012] overflow"
	errInvalidRoutePath       = "[GNOSWAP-ROUTER-013] invalid route path"
	errInvalidRouteFirstToken = "[GNOSWAP-ROUTER-014] invalid route first token"
	errInvalidRouteLastToken  = "[GNOSWAP-ROUTER-015] invalid route last token"
	errInvalidSwapAmount      = "[GNOSWAP-ROUTER-016] invalid swap amount"
	errRouteHopDisconnected   = "[GNOSWAP-ROUTER-017] route hop disconnected"
	errInsufficientBalance    = "[GNOSWAP-ROUTER-018] insufficient balance for swap"
	errSpoofedRealm           = "[GNOSWAP-ROUTER-019] rlm does not match the current crossing frame"
)

// addDetailToError adds detail to an error message.
func addDetailToError(message string, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", message, detail)
	return finalErr.Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
