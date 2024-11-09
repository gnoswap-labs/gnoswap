package staker

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission          = errors.New("[GNOSWAP-GOV_STAKER-001] caller has no permission")
	errNotRegistered         = errors.New("[GNOSWAP-GOV_STAKER-002] not registered token")
	errAlreadyRegistered     = errors.New("[GNOSWAP-GOV_STAKER-003] already registered token")
	errLocked                = errors.New("[GNOSWAP-GOV_STAKER-004] can't transfer token while locked")
	errNoDelegatedAmount     = errors.New("[GNOSWAP-GOV_STAKER-005] zero delegated amount")
	errNoDelegatedTarget     = errors.New("[GNOSWAP-GOV_STAKER-006] did not delegated to that address")
	errNotEnoughDelegated    = errors.New("[GNOSWAP-GOV_STAKER-007] not enough delegated")
	errInvalidAddress        = errors.New("[GNOSWAP-GOV_STAKER-008] invalid address")
	errFutureTime            = errors.New("[GNOSWAP-GOV_STAKER-009] can not use future time")
	errStartTimeAfterEndTime = errors.New("[GNOSWAP-GOV_STAKER-010] start time is after than end time")
	errDataNotFound          = errors.New("[GNOSWAP-GOV_STAKER-011] requested data not found")
	errNotEnoughBalance      = errors.New("[GNOSWAP-GOV_STAKER-012] not enough balance")
	errLessThanMinimum       = errors.New("[GNOSWAP-GOV_STAKER-013] can not delegate less than minimum amount")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
