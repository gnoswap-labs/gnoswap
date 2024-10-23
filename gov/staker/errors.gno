package staker

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission          = errors.New("[GNOSWAP-GOV_STAKER-001] no permission")
	errNotRegistered         = errors.New("[GNOSWAP-GOV_STAKER-002] not registered")
	errAlreadyRegistered     = errors.New("[GNOSWAP-GOV_STAKER-003] already registered")
	errNoDelegatedAmount     = errors.New("[GNOSWAP-GOV_STAKER-004] no delegated amount")
	errNoDelegatedTarget     = errors.New("[GNOSWAP-GOV_STAKER-005] no delegated target")
	errNotEnoughDelegated    = errors.New("[GNOSWAP-GOV_STAKER-006] not enough delegated")
	errInvalidAddress        = errors.New("[GNOSWAP-GOV_STAKER-007] invalid address")
	errFutureTime            = errors.New("[GNOSWAP-GOV_STAKER-008] future time")
	errStartTimeAfterEndTime = errors.New("[GNOSWAP-GOV_STAKER-009] start time after end time")
	errDataNotFound          = errors.New("[GNOSWAP-GOV_STAKER-010] data not found")
	errNotEnoughBalance      = errors.New("[GNOSWAP-GOV_STAKER-011] not enough balance")
	errLessThanMinimum       = errors.New("[GNOSWAP-GOV_STAKER-012] less than minimum")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
