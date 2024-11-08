package launchpad

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-LAUNCHPAD-001] caller has no permission")
	errNotRegistered     = errors.New("[GNOSWAP-LAUNCHPAD-002] not registered token")
	errAlreadyRegistered = errors.New("[GNOSWAP-LAUNCHPAD-003] already registered token")
	errLocked            = errors.New("[GNOSWAP-LAUNCHPAD-004] can't transfer token while locked")
	errInvalidAddress    = errors.New("[GNOSWAP-LAUNCHPAD-005] invalid address")
	errDataNotFound      = errors.New("[GNOSWAP-LAUNCHPAD-006] requested data not found")
	errActiveProject     = errors.New("[GNOSWAP-LAUNCHPAD-007] project is active")
	errInactiveProject   = errors.New("[GNOSWAP-LAUNCHPAD-008] project is inactive")
	errInactiveTier      = errors.New("[GNOSWAP-LAUNCHPAD-009] pool is inactive")
	errInvalidInput      = errors.New("[GNOSWAP-LAUNCHPAD-010] invalid input data")
	errDuplicateProject  = errors.New("[GNOSWAP-LAUNCHPAD-011] can not create same project in same block")
	errInvalidTier       = errors.New("[GNOSWAP-LAUNCHPAD-012] invalid pool")
	errInvalidTierRatio  = errors.New("[GNOSWAP-LAUNCHPAD-013] invalid pool ratio")
	errPastStartTime     = errors.New("[GNOSWAP-LAUNCHPAD-014] can not start from past time")
	errNotEnoughBalance  = errors.New("[GNOSWAP-LAUNCHPAD-015] not enough balance")
	errAlreadyRefunded   = errors.New("[GNOSWAP-LAUNCHPAD-016] already refunded")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
