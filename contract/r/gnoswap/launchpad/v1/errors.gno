package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errNoLeftReward        = "[GNOSWAP-LAUNCHPAD-001] no left reward"
	errInvalidAddress      = "[GNOSWAP-LAUNCHPAD-002] invalid address"
	errDataNotFound        = "[GNOSWAP-LAUNCHPAD-003] requested data not found"
	errInactiveProject     = "[GNOSWAP-LAUNCHPAD-004] project is inactive"
	errInvalidInput        = "[GNOSWAP-LAUNCHPAD-005] invalid input data"
	errDuplicateProject    = "[GNOSWAP-LAUNCHPAD-006] cannot create same project in same block"
	errInvalidTier         = "[GNOSWAP-LAUNCHPAD-007] invalid tier"
	errInsufficientBalance = "[GNOSWAP-LAUNCHPAD-008] insufficient balance"
	errInvalidData         = "[GNOSWAP-LAUNCHPAD-009] invalid data"
	errInvalidAmount       = "[GNOSWAP-LAUNCHPAD-010] invalid amount"
	errInvalidRewardState  = "[GNOSWAP-LAUNCHPAD-011] invalid reward state"
	errNotExistDeposit     = "[GNOSWAP-LAUNCHPAD-012] not exist deposit"
	errAlreadyCollected    = "[GNOSWAP-LAUNCHPAD-013] already collected"
	errInvalidOwner        = "[GNOSWAP-LAUNCHPAD-014] invalid owner"
	errInvalidTime         = "[GNOSWAP-LAUNCHPAD-015] invalid time"
	errNotYetEndedProject  = "[GNOSWAP-LAUNCHPAD-016] project lock period is not over yet"
	errOverflow            = "[GNOSWAP-LAUNCHPAD-017] overflow"
	errSpoofedRealm        = "[GNOSWAP-LAUNCHPAD-018] rlm does not match the current crossing frame"
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
