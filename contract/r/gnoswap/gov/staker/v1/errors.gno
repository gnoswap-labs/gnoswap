package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errTransferFailed      = errors.New("[GNOSWAP-GOV_STAKER-001] transfer failed")
	errInvalidAmount       = errors.New("[GNOSWAP-GOV_STAKER-002] invalid amount")
	errNoDelegatedAmount   = errors.New("[GNOSWAP-GOV_STAKER-003] zero delegated amount")
	errInvalidAddress      = errors.New("[GNOSWAP-GOV_STAKER-004] invalid address")
	errNotEnoughBalance    = errors.New("[GNOSWAP-GOV_STAKER-005] not enough balance")
	errLessThanMinimum     = errors.New("[GNOSWAP-GOV_STAKER-006] cannot delegate less than minimum amount")
	errInvalidSnapshotTime = errors.New("[GNOSWAP-GOV_STAKER-007] invalid snapshot time")
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
