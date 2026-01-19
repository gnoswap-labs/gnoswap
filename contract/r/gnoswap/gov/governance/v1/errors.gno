package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidInput                                   = errors.New("[GNOSWAP-GOVERNANCE-001] invalid input")
	errDataNotFound                                   = errors.New("[GNOSWAP-GOVERNANCE-002] requested data not found")
	errNotEnoughBalance                               = errors.New("[GNOSWAP-GOVERNANCE-003] not enough balance")
	errAlreadyVoted                                   = errors.New("[GNOSWAP-GOVERNANCE-004] cannot vote twice")
	errNotEnoughVotingWeight                          = errors.New("[GNOSWAP-GOVERNANCE-005] not enough voting power")
	errAlreadyCanceledProposal                        = errors.New("[GNOSWAP-GOVERNANCE-006] cannot cancel already canceled proposal")
	errUnableToCancelVotingProposal                   = errors.New("[GNOSWAP-GOVERNANCE-007] unable to cancel voting proposal")
	errTextProposalNotExecutable                      = errors.New("[GNOSWAP-GOVERNANCE-008] cannot execute text proposal")
	errUnableToVoteOutOfPeriod                        = errors.New("[GNOSWAP-GOVERNANCE-009] unable to vote out of voting period")
	errInvalidMessageFormat                           = errors.New("[GNOSWAP-GOVERNANCE-010] invalid message format")
	errAlreadyActiveProposal                          = errors.New("[GNOSWAP-GOVERNANCE-011] already active proposal")
	errProposalNotFound                               = errors.New("[GNOSWAP-GOVERNANCE-012] proposal not found")
	errProposalNotExecutable                          = errors.New("[GNOSWAP-GOVERNANCE-013] proposal not executable")
	errNotProposer                                    = errors.New("[GNOSWAP-GOVERNANCE-014] not proposer")
	errInvalidConfiguration                           = errors.New("[GNOSWAP-GOVERNANCE-015] invalid configuration")
	errInvalidExecution                               = errors.New("[GNOSWAP-GOVERNANCE-016] invalid execution: handler not found")
	errInvalidSmoothingPeriod                         = errors.New("[GNOSWAP-GOVERNANCE-017] invalid smoothing period")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
