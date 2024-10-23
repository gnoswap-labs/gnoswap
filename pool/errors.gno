package pool

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission         = errors.New("[GNOSWAP-POOL-001] no permission")
	errNotRegistered        = errors.New("[GNOSWAP-POOL-002] not registered")
	errAlreadyRegistered    = errors.New("[GNOSWAP-POOL-003] already registered")
	errOutOfRange           = errors.New("[GNOSWAP-POOL-004] out of range")
	errInvalidInput         = errors.New("[GNOSWAP-POOL-005] invalid input")
	errDataNotFound         = errors.New("[GNOSWAP-POOL-006] data not found")
	errLiquidityCalculation = errors.New("[GNOSWAP-POOL-007] liquidity calculation")
	errDuplicateTokenInPool = errors.New("[GNOSWAP-POOL-008] duplicate token in pool")
	errPoolAlreadyExists    = errors.New("[GNOSWAP-POOL-009] pool already exists")
	errLockedPool           = errors.New("[GNOSWAP-POOL-010] locked pool")
	errPriceOutOfRange      = errors.New("[GNOSWAP-POOL-011] price out of range")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
