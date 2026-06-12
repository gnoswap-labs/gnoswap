package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errDataNotFound           = "[GNOSWAP-GOV_STAKER-001] requested data not found"
	errInvalidAmount          = "[GNOSWAP-GOV_STAKER-002] invalid amount"
	errNoDelegatedAmount      = "[GNOSWAP-GOV_STAKER-003] zero delegated amount"
	errNotEnoughDelegated     = "[GNOSWAP-GOV_STAKER-004] not enough delegated"
	errInvalidAddress         = "[GNOSWAP-GOV_STAKER-005] invalid address"
	errNotEnoughBalance       = "[GNOSWAP-GOV_STAKER-006] not enough balance"
	errLessThanMinimum        = "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount"
	errInvalidSnapshotTime    = "[GNOSWAP-GOV_STAKER-008] invalid snapshot time"
	errSameDelegatee          = "[GNOSWAP-GOV_STAKER-009] cannot redelegate to same address"
	errWithdrawNotCollectable = "[GNOSWAP-GOV_STAKER-010] withdraw is not collectable"
	errSpoofedRealm           = "[GNOSWAP-GOV_STAKER-011] rlm does not match the current crossing frame"
)

func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
