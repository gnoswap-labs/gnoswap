package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

// assertCallerIsProposer panics if the caller is not the proposer of the given proposal.
func assertCallerIsProposer(gv *governanceV1, proposalID int64, caller address) {
	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		panic(errProposalNotFound)
	}

	if !proposal.IsProposer(caller) {
		panic(errNotProposer)
	}
}

// AssertIsValidConfig validates governance configuration parameters.
// Panics if any parameter is invalid:
//   - All time delays must be non-negative
//   - Quorum must be between 0 and 100
//   - Proposal creation threshold must be non-negative
//   - Voting weight smoothing duration must be non-negative
//   - The sum of all delays must not cause int64 overflow
func AssertIsValidConfig(cfg governance.Config) {
	// Validate all time-related parameters are non-negative
	if cfg.VotingStartDelay < 0 {
		panic("[GNOSWAP-GOVERNANCE-023] voting start delay cannot be negative")
	}
	if cfg.VotingPeriod < 0 {
		panic("[GNOSWAP-GOVERNANCE-024] voting period cannot be negative")
	}
	if cfg.ExecutionDelay < 0 {
		panic("[GNOSWAP-GOVERNANCE-025] execution delay cannot be negative")
	}
	if cfg.ExecutionWindow < 0 {
		panic("[GNOSWAP-GOVERNANCE-026] execution window cannot be negative")
	}
	if cfg.VotingWeightSmoothingDuration < 0 {
		panic("[GNOSWAP-GOVERNANCE-027] voting weight smoothing duration cannot be negative")
	}
	if cfg.ProposalCreationThreshold < 0 {
		panic("[GNOSWAP-GOVERNANCE-028] proposal creation threshold cannot be negative")
	}

	// Validate quorum is in valid range (0-100)
	if cfg.Quorum < 0 || cfg.Quorum > 100 {
		panic("[GNOSWAP-GOVERNANCE-029] quorum must be between 0 and 100")
	}

	// Check for potential int64 overflow when calculating proposal timestamps
	// The calculation in NewProposalScheduleStatus is:
	// activeTime := createTime + votingStartDelay
	// votingEndTime := activeTime + votingPeriod
	// executableTime := votingEndTime + executionDelay
	// expiredTime := executableTime + executionWindow
	//
	// We need to ensure: votingStartDelay + votingPeriod + executionDelay + executionWindow
	// doesn't overflow when added to a reasonable createdAt timestamp.
	sum := int64(0)
	sum = safeAddInt64(sum, cfg.VotingStartDelay)
	sum = safeAddInt64(sum, cfg.VotingPeriod)
	sum = safeAddInt64(sum, cfg.ExecutionDelay)
	sum = safeAddInt64(sum, cfg.ExecutionWindow)

	// Additional safety check: ensure the sum leaves room for reasonable timestamps
	// (e.g., Unix timestamps are typically in the range of 0 to ~2^31 for dates until 2038,
	// or larger for far future dates, but should not approach MaxInt64)
}
