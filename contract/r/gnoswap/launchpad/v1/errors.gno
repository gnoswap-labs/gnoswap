package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoLeftReward        = errors.New("[GNOSWAP-LAUNCHPAD-001] no left reward")
	errInvalidAddress      = errors.New("[GNOSWAP-LAUNCHPAD-002] invalid address")
	errDataNotFound        = errors.New("[GNOSWAP-LAUNCHPAD-003] requested data not found")
	errInactiveProject     = errors.New("[GNOSWAP-LAUNCHPAD-005] project is inactive")
	errInvalidInput        = errors.New("[GNOSWAP-LAUNCHPAD-007] invalid input data")
	errDuplicateProject    = errors.New("[GNOSWAP-LAUNCHPAD-008] cannot create same project in same block")
	errInvalidTier         = errors.New("[GNOSWAP-LAUNCHPAD-009] invalid tier")
	errInsufficientBalance = errors.New("[GNOSWAP-LAUNCHPAD-010] insufficient balance")
	errInvalidData         = errors.New("[GNOSWAP-LAUNCHPAD-016] invalid data")
	errInvalidAmount       = errors.New("[GNOSWAP-LAUNCHPAD-017] invalid amount")
	errInvalidRewardState  = errors.New("[GNOSWAP-LAUNCHPAD-019] invalid reward state")
	errNotExistDeposit     = errors.New("[GNOSWAP-LAUNCHPAD-020] not exist deposit")
	errAlreadyCollected    = errors.New("[GNOSWAP-LAUNCHPAD-023] already collected")
	errInvalidOwner        = errors.New("[GNOSWAP-LAUNCHPAD-026] invalid owner")
	errInvalidTime         = errors.New("[GNOSWAP-LAUNCHPAD-028] invalid time")
	errNotYetEndedProject  = errors.New("[GNOSWAP-LAUNCHPAD-030] project lock period is not over yet")
	errOverflow            = errors.New("[GNOSWAP-LAUNCHPAD-032] overflow")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
