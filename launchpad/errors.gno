package launchpad

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission        = errors.New("[GNOSWAP-LAUNCHPAD-001] no permission")
	errNotRegistered       = errors.New("[GNOSWAP-LAUNCHPAD-002] not registered")
	errAlreadyRegistered   = errors.New("[GNOSWAP-LAUNCHPAD-003] already registered")
	errDataNotFound        = errors.New("[GNOSWAP-LAUNCHPAD-004] data not found")
	errInactiveProject     = errors.New("[GNOSWAP-LAUNCHPAD-005] inactive project")
	errInactiveTier        = errors.New("[GNOSWAP-LAUNCHPAD-006] inactive tier")
	errInvalidInput        = errors.New("[GNOSWAP-LAUNCHPAD-007] invalid input")
	errDuplicateProject    = errors.New("[GNOSWAP-LAUNCHPAD-008] duplicate project")
	errInvalidTierRatio    = errors.New("[GNOSWAP-LAUNCHPAD-009] invalid tier ratio")
	errPastStartTime       = errors.New("[GNOSWAP-LAUNCHPAD-010] past start time")
	errInsufficientBalance = errors.New("[GNOSWAP-LAUNCHPAD-011] insufficient balance")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
