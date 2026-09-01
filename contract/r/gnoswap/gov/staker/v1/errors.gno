package staker

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errDataNotFound                   = "[GNOSWAP-GOV_STAKER-001] requested data not found"
	errInvalidAmount                  = "[GNOSWAP-GOV_STAKER-002] invalid amount"
	errNoDelegatedAmount              = "[GNOSWAP-GOV_STAKER-003] zero delegated amount"
	errNotEnoughDelegated             = "[GNOSWAP-GOV_STAKER-004] not enough delegated"
	errInvalidAddress                 = "[GNOSWAP-GOV_STAKER-005] invalid address"
	errNotEnoughBalance               = "[GNOSWAP-GOV_STAKER-006] not enough balance"
	errLessThanMinimum                = "[GNOSWAP-GOV_STAKER-007] cannot delegate less than minimum amount"
	errInvalidSnapshotTime            = "[GNOSWAP-GOV_STAKER-008] invalid snapshot time"
	errSameDelegatee                  = "[GNOSWAP-GOV_STAKER-009] cannot redelegate to same address"
	errWithdrawNotCollectable         = "[GNOSWAP-GOV_STAKER-010] withdraw is not collectable"
	errAmountMustBeNonNegative        = "[GNOSWAP-GOV_STAKER-011] amount must be non-negative"
	errTotalStakedAmountOverflow      = "[GNOSWAP-GOV_STAKER-012] total staked amount would overflow"
	errRemoveAmountExceedsTotalStaked = "[GNOSWAP-GOV_STAKER-013] remove amount exceeds total staked amount"
	errRemoveAmountExceedsStaked      = "[GNOSWAP-GOV_STAKER-014] remove amount exceeds staked amount"
	errAmountMustBePositive           = "[GNOSWAP-GOV_STAKER-015] amount must be positive"
	errRewardDebtUpdateRequired       = "[GNOSWAP-GOV_STAKER-016] must update reward debt before claiming rewards"
	errDelegatedAmountNegative        = "[GNOSWAP-GOV_STAKER-017] delegated amount cannot be negative"
	errUndelegationAmountNegative     = "[GNOSWAP-GOV_STAKER-018] undelegation amount cannot be negative"
	errDelegationNotFound             = "[GNOSWAP-GOV_STAKER-019] delegation not found"
)

func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
