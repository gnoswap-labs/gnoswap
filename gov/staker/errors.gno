package staker

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission          = errors.New("[GNOSWAP-GOV_STAKER-001] no permission")
	errNotRegistered         = errors.New("[GNOSWAP-GOV_STAKER-002] not registered")
	errAlreadyRegistered     = errors.New("[GNOSWAP-GOV_STAKER-003] already registered")
	errLocked                = errors.New("[GNOSWAP-GOV_STAKER-004] can't transfer token while locked")
	errNoDelegatedAmount     = errors.New("[GNOSWAP-GOV_STAKER-005] no delegated amount")
	errNoDelegatedTarget     = errors.New("[GNOSWAP-GOV_STAKER-006] no delegated target")
	errNotEnoughDelegated    = errors.New("[GNOSWAP-GOV_STAKER-007] not enough delegated")
	errInvalidAddress        = errors.New("[GNOSWAP-GOV_STAKER-008] invalid address")
	errFutureTime            = errors.New("[GNOSWAP-GOV_STAKER-009] future time")
	errStartTimeAfterEndTime = errors.New("[GNOSWAP-GOV_STAKER-010] start time after end time")
	errDataNotFound          = errors.New("[GNOSWAP-GOV_STAKER-011] data not found")
	errNotEnoughBalance      = errors.New("[GNOSWAP-GOV_STAKER-012] not enough balance")
	errLessThanMinimum       = errors.New("[GNOSWAP-GOV_STAKER-013] less than minimum")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
