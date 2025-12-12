package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission       = errors.New("[GNOSWAP-GOV_STAKER-001] caller has no permission")
	errDataNotFound       = errors.New("[GNOSWAP-GOV_STAKER-002] requested data not found")
	errTransferFailed     = errors.New("[GNOSWAP-GOV_STAKER-003] transfer failed")
	errInvalidAmount      = errors.New("[GNOSWAP-GOV_STAKER-004] invalid amount")
	errNoDelegatedAmount  = errors.New("[GNOSWAP-GOV_STAKER-005] zero delegated amount")
	errNoDelegatedTarget  = errors.New("[GNOSWAP-GOV_STAKER-006] did not delegate to that address")
	errNotEnoughDelegated = errors.New("[GNOSWAP-GOV_STAKER-007] not enough delegated")
	errInvalidAddress     = errors.New("[GNOSWAP-GOV_STAKER-008] invalid address")
	errFutureTime         = errors.New("[GNOSWAP-GOV_STAKER-009] cannot use future time")
	errNotEnoughBalance   = errors.New("[GNOSWAP-GOV_STAKER-010] not enough balance")
	errLessThanMinimum    = errors.New("[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount")
)

func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}

// checkTransferError checks transfer error.
func checkTransferError(err error) {
	if err != nil {
		panic(makeErrorWithDetails(errTransferFailed, err.Error()))
	}
}
