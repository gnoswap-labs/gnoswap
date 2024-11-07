package pool

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission              = errors.New("[GNOSWAP-POOL-001] no permission")
	errNotRegistered             = errors.New("[GNOSWAP-POOL-002] not registered")
	errAlreadyRegistered         = errors.New("[GNOSWAP-POOL-003] already registered")
	errLocked                    = errors.New("[GNOSWAP-POOL-004] can't transfer token while locked")
	errOutOfRange                = errors.New("[GNOSWAP-POOL-005] out of range")
	errInvalidInput              = errors.New("[GNOSWAP-POOL-006] invalid input")
	errInvalidPositionKey        = errors.New("[GNOSWAP-POOL-007] invalid position key")
	errDataNotFound              = errors.New("[GNOSWAP-POOL-008] data not found")
	errLiquidityCalculation      = errors.New("[GNOSWAP-POOL-009] liquidity calculation")
	errZeroLiquidity             = errors.New("[GNOSWAP-POOL-010] zero liquidity")
	errDuplicateTokenInPool      = errors.New("[GNOSWAP-POOL-011] duplicate token in pool")
	errTokenSortOrder            = errors.New("[GNOSWAP-POOL-012] token sort order")
	errPoolAlreadyExists         = errors.New("[GNOSWAP-POOL-013] pool already exists")
	errInvalidSwapAmount         = errors.New("[GNOSWAP-POOL-014] invalid swap amount")
	errInvalidPotocolFeePct      = errors.New("[GNOSWAP-POOL-015] invalid protocol fee pct")
	errInvalidWithdrawalFeePct   = errors.New("[GNOSWAP-POOL-016] invalid withdrawal fee pct")
	errLockedPool                = errors.New("[GNOSWAP-POOL-017] locked pool")
	errPriceOutOfRange           = errors.New("[GNOSWAP-POOL-018] price out of range")
	errNotEnoughBalance          = errors.New("[GNOSWAP-POOL-019] not enough balance")
	errMustBeNegative            = errors.New("[GNOSWAP-POOL-020] must be negative")
	errTransferFailed            = errors.New("[GNOSWAP-POOL-021] transfer failed")
	errInvalidTickAndTickSpacing = errors.New("[GNOSWAP-POOL-022] invalid tick and tick spacing")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
