package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

// Error definitions for pool operations
var (
	errUnsupportedFeeTier        = errors.New("[GNOSWAP-POOL-001] unsupported fee tier")
	errPoolAlreadyExists         = errors.New("[GNOSWAP-POOL-002] pool already created")
	errOutOfRange                = errors.New("[GNOSWAP-POOL-003] out of range for numeric value")
	errInvalidInput              = errors.New("[GNOSWAP-POOL-004] invalid input data")
	errInvalidPositionKey        = errors.New("[GNOSWAP-POOL-005] invalid position key")
	errDataNotFound              = errors.New("[GNOSWAP-POOL-006] requested data not found")
	errLiquidityCalculation      = errors.New("[GNOSWAP-POOL-007] invalid liquidity calculated")
	errZeroLiquidity             = errors.New("[GNOSWAP-POOL-008] zero liquidity")
	errDuplicateTokenInPool      = errors.New("[GNOSWAP-POOL-009] same token used in single pool")
	errTokenSortOrder            = errors.New("[GNOSWAP-POOL-010] tokens must be in lexicographical order")
	errTickLowerInvalid          = errors.New("[GNOSWAP-POOL-011] tickLower is invalid")
	errTickUpperInvalid          = errors.New("[GNOSWAP-POOL-012] tickUpper is invalid")
	errInvalidSwapAmount         = errors.New("[GNOSWAP-POOL-013] invalid swap amount")
	errInvalidProtocolFeePct     = errors.New("[GNOSWAP-POOL-014] invalid protocol fee percentage")
	errInvalidWithdrawalFeePct   = errors.New("[GNOSWAP-POOL-015] invalid withdrawal fee percentage")
	errLockedPool                = errors.New("[GNOSWAP-POOL-016] can't swap while pool is locked")
	errPriceOutOfRange           = errors.New("[GNOSWAP-POOL-017] swap price out of range")
	errTransferFailed            = errors.New("[GNOSWAP-POOL-018] token transfer failed")
	errInvalidTickAndTickSpacing = errors.New("[GNOSWAP-POOL-019] invalid tick and tick spacing requested")
	errInvalidTickRange          = errors.New("[GNOSWAP-POOL-020] tickLower is greater than or equal to tickUpper")
	errUnderflow                 = errors.New("[GNOSWAP-POOL-021] underflow")
	errOverFlow                  = errors.New("[GNOSWAP-POOL-022] overflow")
	errBalanceUpdateFailed       = errors.New("[GNOSWAP-POOL-023] balance update failed")
	errInvalidPayer              = errors.New("[GNOSWAP-POOL-024] invalid payer")
	errNotAccessEOA              = errors.New("[GNOSWAP-POOL-025] not access EOA")
	errInsufficientPayment       = errors.New("[GNOSWAP-POOL-026] insufficient payment")
	errNotInitializedObservation = errors.New("[GNOSWAP-POOL-027] not initialized observation")
)

// newErrorWithDetail adds detail to an error message.
func newErrorWithDetail(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
