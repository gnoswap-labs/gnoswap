package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidInput                                   = errors.New("[GNOSWAP-GOVERNANCE-002] invalid input")
	errDataNotFound                                   = errors.New("[GNOSWAP-GOVERNANCE-003] requested data not found")
	errNotEnoughBalance                               = errors.New("[GNOSWAP-GOVERNANCE-004] not enough balance")
	errAlreadyVoted                                   = errors.New("[GNOSWAP-GOVERNANCE-006] cannot vote twice")
	errNotEnoughVotingWeight                          = errors.New("[GNOSWAP-GOVERNANCE-007] not enough voting power")
	errAlreadyCanceledProposal                        = errors.New("[GNOSWAP-GOVERNANCE-008] cannot cancel already canceled proposal")
	errUnableToCancelVotingProposal                   = errors.New("[GNOSWAP-GOVERNANCE-009] unable to cancel voting proposal")
	errTextProposalNotExecutable                      = errors.New("[GNOSWAP-GOVERNANCE-011] cannot execute text proposal")
	errUnableToVoteOutOfPeriod                        = errors.New("[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period")
	errInvalidMessageFormat                           = errors.New("[GNOSWAP-GOVERNANCE-015] invalid message format")
	errAlreadyActiveProposal                          = errors.New("[GNOSWAP-GOVERNANCE-019] already active proposal")
	errProposalNotFound                               = errors.New("[GNOSWAP-GOVERNANCE-020] proposal not found")
	errProposalNotExecutable                          = errors.New("[GNOSWAP-GOVERNANCE-021] proposal not executable")
	errNotProposer                                    = errors.New("[GNOSWAP-GOVERNANCE-022] not proposer")
	errInvalidConfiguration                           = errors.New("[GNOSWAP-GOVERNANCE-023] invalid configuration")
	errInvalidExecution                               = errors.New("[GNOSWAP-GOVERNANCE-024] invalid execution: handler not found")
	errInvalidSmoothingPeriod                         = errors.New("[GNOSWAP-GOVERNANCE-025] invalid smoothing period")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
