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

// assertIsValidConfigRanges validates that all config values are within valid ranges.
// Panics if any parameter is invalid:
//   - All time delays and thresholds must be non-negative
//   - Quorum must be between 0 and 100
func assertIsValidConfigRanges(cfg governance.Config) {
	if cfg.VotingStartDelay < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "votingStartDelay cannot be negative"))
	}
	if cfg.VotingPeriod < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "votingPeriod cannot be negative"))
	}
	if cfg.ExecutionDelay < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "executionDelay cannot be negative"))
	}
	if cfg.ExecutionWindow < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "executionWindow cannot be negative"))
	}
	if cfg.VotingWeightSmoothingDuration < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "votingWeightSmoothingDuration cannot be negative"))
	}
	if cfg.ProposalCreationThreshold < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "proposalCreationThreshold cannot be negative"))
	}

	// Validate quorum is in valid range (0-100)
	if cfg.Quorum < 0 || cfg.Quorum > 100 {
		panic(makeErrorWithDetails(errOutOfRange, "quorum must be between 0 and 100"))
	}
}

// assertIsNotOverflowDelay checks if summing config delays causes overflow.
// This is a pure function without time dependency for easier testing.
func assertIsNotOverflowDelay(cfg governance.Config) {
	sum := int64(0)

	sum += cfg.VotingStartDelay
	if sum < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "timestamp calculations may cause overflow"))
	}

	sum += cfg.VotingPeriod
	if sum < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "timestamp calculations may cause overflow"))
	}

	sum += cfg.ExecutionDelay
	if sum < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "timestamp calculations may cause overflow"))
	}

	sum += cfg.ExecutionWindow
	if sum < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "timestamp calculations may cause overflow"))
	}
}

// assertIsNotOverflowSchdule checks if adding a delay to current time causes overflow.
func assertIsNotOverflowSchdule(currentTime, totalDelay int64) {
	if currentTime+totalDelay < 0 {
		panic(makeErrorWithDetails(errOutOfRange, "timestamp calculations may cause overflow"))
	}
}
