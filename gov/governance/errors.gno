package governance

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission                                   = errors.New("[GNOSWAP-GOVERNANCE-001] caller has no permission")
	errOutOfRange                                     = errors.New("[GNOSWAP-GOVERNANCE-002] out of range for numeric value")
	errInvalidInput                                   = errors.New("[GNOSWAP-GOVERNANCE-003] invalid input")
	errDataNotFound                                   = errors.New("[GNOSWAP-GOVERNANCE-004] requested data not found")
	errNotEnoughBalance                               = errors.New("[GNOSWAP-GOVERNANCE-005] not enough balance")
	errUnableToVoteBeforeStarting                     = errors.New("[GNOSWAP-GOVERNANCE-006] unable to vote before starts")
	errUnableToVoteAfterEnding                        = errors.New("[GNOSWAP-GOVERNANCE-007] unable to vote after ends")
	errUnableToVoteCanceledProposal                   = errors.New("[GNOSWAP-GOVERNANCE-008] unable to vote for canceled proposal")
	errAlreadyVoted                                   = errors.New("[GNOSWAP-GOVERNANCE-009] can not vote twice")
	errNotEnoughVotingWeight                          = errors.New("[GNOSWAP-GOVERNANCE-010] not enough voting power")
	errAlreadyCanceledProposal                        = errors.New("[GNOSWAP-GOVERNANCE-011] can not cancel already canceled proposal")
	errUnableToCancleVotingProposal                   = errors.New("[GNOSWAP-GOVERNANCE-012] unable to cancel voting proposal")
	errUnableToCancelProposalWithVoterEnoughDelegated = errors.New("[GNOSWAP-GOVERNANCE-013] unable to cancel proposal with voter has enough delegation")
	errTextProposalNotExecutable                      = errors.New("[GNOSWAP-GOVERNANCE-014] can not execute text proposal")
	errUnableToExecuteProposal                        = errors.New("[GNOSWAP-GOVERNANCE-015] unable to execute proposal")
	errBeforeProposalExecutionTime                    = errors.New("[GNOSWAP-GOVERNANCE-016] proposal execution time has not been reached yet")
	errProposalExecutionTimeExpired                   = errors.New("[GNOSWAP-GOVERNANCE-017] proposal execution time expired")
	errProposalQuorumNotSatisfied                     = errors.New("[GNOSWAP-GOVERNANCE-018] proposal quorum not met")
	errMoreNoVotesThanYesVotes                        = errors.New("[GNOSWAP-GOVERNANCE-019] proposal hasmore no vote than yes vote")
	errInvalidFunctionParameters                      = errors.New("[GNOSWAP-GOVERNANCE-020] invalid function parameter to execute")
	errNonExecutableFunction                          = errors.New("[GNOSWAP-GOVERNANCE-021] not executable function")
	errParseUintFailed                                = errors.New("[GNOSWAP-GOVERNANCE-022] parseUint internal failed")
	errUnsupportedProposalType                        = errors.New("[GNOSWAP-GOVERNANCE-023] unsupported proposal type")
	errNotRegisteredToCommunityPool                   = errors.New("[GNOSWAP-GOVERNANCE-024] token not registered to community pool")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
