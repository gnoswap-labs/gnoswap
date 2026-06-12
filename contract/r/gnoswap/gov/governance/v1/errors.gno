package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidInput                 = "[GNOSWAP-GOVERNANCE-001] invalid input"
	errDataNotFound                 = "[GNOSWAP-GOVERNANCE-002] requested data not found"
	errNotEnoughBalance             = "[GNOSWAP-GOVERNANCE-003] not enough balance"
	errAlreadyVoted                 = "[GNOSWAP-GOVERNANCE-004] cannot vote twice"
	errNotEnoughVotingWeight        = "[GNOSWAP-GOVERNANCE-005] not enough voting power"
	errAlreadyCanceledProposal      = "[GNOSWAP-GOVERNANCE-006] cannot cancel already canceled proposal"
	errUnableToCancelVotingProposal = "[GNOSWAP-GOVERNANCE-007] unable to cancel voting proposal"
	errTextProposalNotExecutable    = "[GNOSWAP-GOVERNANCE-008] cannot execute text proposal"
	errUnableToVoteOutOfPeriod      = "[GNOSWAP-GOVERNANCE-009] unable to vote out of voting period"
	errInvalidMessageFormat         = "[GNOSWAP-GOVERNANCE-010] invalid message format"
	errAlreadyActiveProposal        = "[GNOSWAP-GOVERNANCE-011] already active proposal"
	errProposalNotFound             = "[GNOSWAP-GOVERNANCE-012] proposal not found"
	errProposalNotExecutable        = "[GNOSWAP-GOVERNANCE-013] proposal not executable"
	errNotProposer                  = "[GNOSWAP-GOVERNANCE-014] not proposer"
	errInvalidConfiguration         = "[GNOSWAP-GOVERNANCE-015] invalid configuration"
	errInvalidExecution             = "[GNOSWAP-GOVERNANCE-016] invalid execution: handler not found"
	errInvalidSmoothingPeriod       = "[GNOSWAP-GOVERNANCE-017] invalid smoothing period"
	errSpoofedRealm                 = "[GNOSWAP-GOVERNANCE-018] spoofed realm: captured cur no longer matches live frame"
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
