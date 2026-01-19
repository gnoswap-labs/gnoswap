package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errDataNotFound           = errors.New("[GNOSWAP-GOV_STAKER-002] requested data not found")
	errInvalidAmount          = errors.New("[GNOSWAP-GOV_STAKER-004] invalid amount")
	errNoDelegatedAmount      = errors.New("[GNOSWAP-GOV_STAKER-005] zero delegated amount")
	errNotEnoughDelegated     = errors.New("[GNOSWAP-GOV_STAKER-007] not enough delegated")
	errInvalidAddress         = errors.New("[GNOSWAP-GOV_STAKER-008] invalid address")
	errNotEnoughBalance       = errors.New("[GNOSWAP-GOV_STAKER-010] not enough balance")
	errLessThanMinimum        = errors.New("[GNOSWAP-GOV_STAKER-011] cannot delegate less than minimum amount")
	errInvalidSnapshotTime    = errors.New("[GNOSWAP-GOV_STAKER-012] invalid snapshot time")
	errSameDelegatee          = errors.New("[GNOSWAP-GOV_STAKER-013] cannot redelegate to same address")
	errActiveProposal         = errors.New("[GNOSWAP-GOV_STAKER-014] cannot undelegate during active proposal")
	errWithdrawNotCollectable = errors.New("[GNOSWAP-GOV_STAKER-015] withdraw is not collectable")
)

func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
