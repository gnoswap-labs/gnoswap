package v1

import (
	"math"
	"time"

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

// assertIsValidConfig validates governance configuration parameters.
// Panics if any parameter is invalid:
//   - All time delays and thresholds must be non-negative
//   - Quorum must be between 0 and 100
//   - The sum of all delays must not cause int64 overflow when added to current time
func assertIsValidConfig(cfg governance.Config) {
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

	// Check for potential int64 overflow when calculating proposal timestamps
	// Simulate the same calculation with current time to detect overflow at each step
	currentTime := time.Now().Unix()
	if cfg.VotingStartDelay > 0 && currentTime > math.MaxInt64-cfg.VotingStartDelay {
		panic(makeErrorWithDetails(errOutOfRange, "currentTime + votingStartDelay exceeds MaxInt64"))
	}

	activeTime := currentTime + cfg.VotingStartDelay
	if cfg.VotingPeriod > 0 && activeTime > math.MaxInt64-cfg.VotingPeriod {
		panic(makeErrorWithDetails(errOutOfRange, "activeTime + votingPeriod exceeds MaxInt64"))
	}

	votingEndTime := activeTime + cfg.VotingPeriod
	if cfg.ExecutionDelay > 0 && votingEndTime > math.MaxInt64-cfg.ExecutionDelay {
		panic(makeErrorWithDetails(errOutOfRange, "votingEndTime + executionDelay exceeds MaxInt64"))
	}

	executableTime := votingEndTime + cfg.ExecutionDelay
	if cfg.ExecutionWindow > 0 && executableTime > math.MaxInt64-cfg.ExecutionWindow {
		panic(makeErrorWithDetails(errOutOfRange, "executableTime + executionWindow exceeds MaxInt64"))
	}
}
