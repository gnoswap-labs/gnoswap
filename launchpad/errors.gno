package launchpad

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoLeftReward       = errors.New("[GNOSWAP-LAUNCHPAD-001] no left reward")
	errInvalidAddress     = errors.New("[GNOSWAP-LAUNCHPAD-002] invalid address")
	errDataNotFound       = errors.New("[GNOSWAP-LAUNCHPAD-003] requested data not found")
	errActiveProject      = errors.New("[GNOSWAP-LAUNCHPAD-004] project is active")
	errInactiveProject    = errors.New("[GNOSWAP-LAUNCHPAD-005] project is inactive")
	errInactiveTier       = errors.New("[GNOSWAP-LAUNCHPAD-006] pool is inactive")
	errInvalidInput       = errors.New("[GNOSWAP-LAUNCHPAD-007] invalid input data")
	errDuplicateProject   = errors.New("[GNOSWAP-LAUNCHPAD-008] can not create same project in same block")
	errInvalidTier        = errors.New("[GNOSWAP-LAUNCHPAD-009] invalid pool")
	errInvalidTierRatio   = errors.New("[GNOSWAP-LAUNCHPAD-010] invalid pool ratio")
	errInvalidLength      = errors.New("[GNOSWAP-LAUNCHPAD-011] invalid length")
	errNotEnoughBalance   = errors.New("[GNOSWAP-LAUNCHPAD-012] not enough balance")
	errInvalidCondition   = errors.New("[GNOSWAP-LAUNCHPAD-013] invalid transfer condition")
	errConvertFail        = errors.New("[GNOSWAP-LAUNCHPAD-014] convert fail")
	errNotUserCaller      = errors.New("[GNOSWAP-LAUNCHPAD-015] only user caller")
	errInvalidProjectTier = errors.New("[GNOSWAP-LAUNCHPAD-016] invalid project tier")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
