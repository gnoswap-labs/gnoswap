package governance

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission                                   = errors.New("[GNOSWAP-GOVERNANCE-001] no permission")
	errOutOfRange                                     = errors.New("[GNOSWAP-GOVERNANCE-002] value out of range")
	errInvalidInput                                   = errors.New("[GNOSWAP-GOVERNANCE-003] invalid input")
	errDataNotFound                                   = errors.New("[GNOSWAP-GOVERNANCE-004] data not found")
	errNotEnoughBalance                               = errors.New("[GNOSWAP-GOVERNANCE-005] not enough balance")
	errUnableToVoteBeforeStarting                     = errors.New("[GNOSWAP-GOVERNANCE-006] unable to vote before starting")
	errUnableToVoteAfterEnding                        = errors.New("[GNOSWAP-GOVERNANCE-007] unable to vote after ending")
	errUnableToVoteCanceledProposal                   = errors.New("[GNOSWAP-GOVERNANCE-008] unable to vote canceled proposal")
	errAlreadyVoted                                   = errors.New("[GNOSWAP-GOVERNANCE-009] already voted")
	errNotEnoughVotingWeight                          = errors.New("[GNOSWAP-GOVERNANCE-010] not enough voting weight")
	errAlreadyCanceledProposal                        = errors.New("[GNOSWAP-GOVERNANCE-011] already canceled proposal")
	errUnableToCancleVotingProposal                   = errors.New("[GNOSWAP-GOVERNANCE-012] unable to cancel voting proposal")
	errUnableToCancelProposalWithVoterEnoughDelegated = errors.New("[GNOSWAP-GOVERNANCE-013] unable to cancel proposal with voter enough delegated")
	errTextProposalNotExecutable                      = errors.New("[GNOSWAP-GOVERNANCE-014] text proposal not executable")
	errUnableToExecuteProposal                        = errors.New("[GNOSWAP-GOVERNANCE-015] unable to execute proposal")
	errBeforeProposalExecutionTime                    = errors.New("[GNOSWAP-GOVERNANCE-016] proposal execution time has not been reached yet")
	errProposalExecutionTimeExpired                   = errors.New("[GNOSWAP-GOVERNANCE-017] proposal execution time expired")
	errProposalQuorumNotSatisfied                     = errors.New("[GNOSWAP-GOVERNANCE-018] proposal quorum not met")
	errMoreNoVotesThanYesVotes                        = errors.New("[GNOSWAP-GOVERNANCE-019] more no votes than yes votes")
	errInvalidFunctionParameters                      = errors.New("[GNOSWAP-GOVERNANCE-020] invalid function parameters")
	errNonExecutableFunction                          = errors.New("[GNOSWAP-GOVERNANCE-021] non-executable function")
	errParseUintFailed                                = errors.New("[GNOSWAP-GOVERNANCE-022] parseUint failed")
	errUnsupportedProposalType                        = errors.New("[GNOSWAP-GOVERNANCE-023] unsupported proposal type")
	errNotRegisteredToCommunityPool                   = errors.New("[GNOSWAP-GOVERNANCE-024] not registered to community pool")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
