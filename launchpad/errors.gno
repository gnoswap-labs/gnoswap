package launchpad

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission        = errors.New("[GNOSWAP-LAUNCHPAD-001] no permission")
	errNotRegistered       = errors.New("[GNOSWAP-LAUNCHPAD-002] not registered")
	errAlreadyRegistered   = errors.New("[GNOSWAP-LAUNCHPAD-003] already registered")
	errLocked              = errors.New("[GNOSWAP-LAUNCHPAD-004] can't transfer token while locked")
	errInvalidAddress      = errors.New("[GNOSWAP-LAUNCHPAD-005] invalid address")
	errDataNotFound        = errors.New("[GNOSWAP-LAUNCHPAD-006] data not found")
	errActiveProject       = errors.New("[GNOSWAP-LAUNCHPAD-007] active project")
	errInactiveProject     = errors.New("[GNOSWAP-LAUNCHPAD-008] inactive project")
	errInactiveTier        = errors.New("[GNOSWAP-LAUNCHPAD-009] inactive tier")
	errInvalidInput        = errors.New("[GNOSWAP-LAUNCHPAD-010] invalid input")
	errDuplicateProject    = errors.New("[GNOSWAP-LAUNCHPAD-011] duplicate project")
	errInvalidTier         = errors.New("[GNOSWAP-LAUNCHPAD-012] invalid tier")
	errInvalidTierRatio    = errors.New("[GNOSWAP-LAUNCHPAD-013] invalid tier ratio")
	errPastStartTime       = errors.New("[GNOSWAP-LAUNCHPAD-014] past start time")
	errInsufficientBalance = errors.New("[GNOSWAP-LAUNCHPAD-015] insufficient balance")
	errNotEnoughBalance    = errors.New("[GNOSWAP-LAUNCHPAD-016] not enough balance")
	errAlreadyRefunded     = errors.New("[GNOSWAP-LAUNCHPAD-017] already refunded")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
