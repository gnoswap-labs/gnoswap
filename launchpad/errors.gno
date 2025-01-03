package launchpad

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoLeftReward     = errors.New("[GNOSWAP-LAUNCHPAD-001] no left reward")
	errInvalidAddress   = errors.New("[GNOSWAP-LAUNCHPAD-002] invalid address")
	errDataNotFound     = errors.New("[GNOSWAP-LAUNCHPAD-003] requested data not found")
	errActiveProject    = errors.New("[GNOSWAP-LAUNCHPAD-004] project is active")
	errInactiveProject  = errors.New("[GNOSWAP-LAUNCHPAD-005] project is inactive")
	errInactiveTier     = errors.New("[GNOSWAP-LAUNCHPAD-006] pool is inactive")
	errInvalidInput     = errors.New("[GNOSWAP-LAUNCHPAD-007] invalid input data")
	errDuplicateProject = errors.New("[GNOSWAP-LAUNCHPAD-008] can not create same project in same block")
	errInvalidTier      = errors.New("[GNOSWAP-LAUNCHPAD-009] invalid pool")
	errInvalidTierRatio = errors.New("[GNOSWAP-LAUNCHPAD-010] invalid pool ratio")
	errPastStartTime    = errors.New("[GNOSWAP-LAUNCHPAD-011] can not start from past time")
	errNotEnoughBalance = errors.New("[GNOSWAP-LAUNCHPAD-012] not enough balance")
	errAlreadyRefunded  = errors.New("[GNOSWAP-LAUNCHPAD-013] already refunded")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
