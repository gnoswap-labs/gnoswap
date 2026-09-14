package pool

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Error definitions for pool operations
const (
	errUnsupportedFeeTier        = "[GNOSWAP-POOL-001] unsupported fee tier"
	errPoolAlreadyExists         = "[GNOSWAP-POOL-002] pool already created"
	errOutOfRange                = "[GNOSWAP-POOL-003] out of range for numeric value"
	errInvalidInput              = "[GNOSWAP-POOL-004] invalid input data"
	errDataNotFound              = "[GNOSWAP-POOL-005] requested data not found"
	errLiquidityCalculation      = "[GNOSWAP-POOL-006] invalid liquidity calculated"
	errZeroLiquidity             = "[GNOSWAP-POOL-007] zero liquidity"
	errDuplicateTokenInPool      = "[GNOSWAP-POOL-008] same token used in single pool"
	errTickLowerInvalid          = "[GNOSWAP-POOL-009] tickLower is invalid"
	errTickUpperInvalid          = "[GNOSWAP-POOL-010] tickUpper is invalid"
	errInvalidSwapAmount         = "[GNOSWAP-POOL-011] invalid swap amount"
	errInvalidProtocolFeePct     = "[GNOSWAP-POOL-012] invalid protocol fee percentage"
	errInvalidWithdrawalFeePct   = "[GNOSWAP-POOL-013] invalid withdrawal fee percentage"
	errLockedPool                = "[GNOSWAP-POOL-014] cannot modify pool while locked"
	errPriceOutOfRange           = "[GNOSWAP-POOL-015] swap price out of range"
	errTransferFailed            = "[GNOSWAP-POOL-016] token transfer failed"
	errInvalidTickAndTickSpacing = "[GNOSWAP-POOL-017] invalid tick and tick spacing requested"
	errInvalidTickRange          = "[GNOSWAP-POOL-018] tickLower is greater than or equal to tickUpper"
	errUnderflow                 = "[GNOSWAP-POOL-019] underflow"
	errOverflow                  = "[GNOSWAP-POOL-020] overflow"
	errBalanceUpdateFailed       = "[GNOSWAP-POOL-021] balance update failed"
	errNotAccessEOA              = "[GNOSWAP-POOL-022] not access EOA"
	errInsufficientPayment       = "[GNOSWAP-POOL-023] insufficient payment"
	errNotInitializedObservation = "[GNOSWAP-POOL-024] not initialized observation"
	errObservationTooOld         = "[GNOSWAP-POOL-025] target timestamp before oldest observation"
	errObservationBeforeEpoch    = "[GNOSWAP-POOL-026] lookback window starts before unix epoch"
	errInsufficientPoolBalance   = "[GNOSWAP-POOL-027] insufficient pool balance for swap"
)

// newErrorWithDetail adds detail to an error message.
func newErrorWithDetail(message string, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", message, detail)
	return finalErr.Error()
}

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
