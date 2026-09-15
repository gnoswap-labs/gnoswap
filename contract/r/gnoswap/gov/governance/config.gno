package governance

import (
	"errors"

	bptree "gno.land/p/nt/bptree/v0"
)

// Config represents the configuration of the governor contract.
// All parameters can be modified through Reconfigure by admin or governance.
type Config struct {
	// VotingStartDelay is the delay before voting starts after proposal creation (in seconds)
	VotingStartDelay int64
	// VotingPeriod is the duration during which votes are collected (in seconds)
	VotingPeriod int64
	// VotingWeightSmoothingDuration is the period over which voting weight is averaged
	// for proposal creation and cancellation threshold calculations (in seconds).
	VotingWeightSmoothingDuration int64
	// Quorum is the percentage of total xGNS supply required for proposal approval.
	// Total supply includes xGNS held by the launchpad.
	Quorum int64
	// ProposalCreationThreshold is the minimum xGNS amount required to create a proposal
	ProposalCreationThreshold int64
	// ExecutionDelay is the waiting period after voting ends before a proposal can be executed (in seconds)
	ExecutionDelay int64
	// ExecutionWindow is the time window during which an approved proposal can be executed (in seconds)
	ExecutionWindow int64
}

// IsValid reports whether the configuration's durations, threshold, quorum, and
// cumulative schedule values satisfy the governance validation constraints.
//
// Parameters:
//   - currentTime: current time value included when checking that the cumulative schedule does not become negative
//
// Returns:
//   - error: nil when all fields and cumulative values are valid; otherwise an error describing the first invalid value
func (c Config) IsValid(currentTime int64) error {
	if c.VotingStartDelay < 0 {
		return errors.New("votingStartDelay cannot be negative")
	}

	if c.VotingPeriod < 0 {
		return errors.New("votingPeriod cannot be negative")
	}

	if c.ExecutionDelay < 0 {
		return errors.New("executionDelay cannot be negative")
	}

	if c.ExecutionWindow < 0 {
		return errors.New("executionWindow cannot be negative")
	}

	if c.VotingWeightSmoothingDuration < 0 {
		return errors.New("votingWeightSmoothingDuration cannot be negative")
	}

	if c.ProposalCreationThreshold < 0 {
		return errors.New("proposalCreationThreshold cannot be negative")
	}

	if c.Quorum < 0 || c.Quorum > 100 {
		return errors.New("quorum must be between 0 and 100")
	}

	sum := int64(0)

	sum += c.VotingStartDelay
	if sum < 0 {
		return errors.New("votingStartDelay cannot be negative")
	}

	sum += c.VotingPeriod
	if sum < 0 {
		return errors.New("votingPeriod cannot be negative")
	}

	sum += c.ExecutionDelay
	if sum < 0 {
		return errors.New("executionDelay cannot be negative")
	}

	sum += c.ExecutionWindow
	if sum < 0 {
		return errors.New("executionWindow cannot be negative")
	}

	sum += currentTime
	if sum < 0 {
		return errors.New("total delay cannot be negative")
	}

	return nil
}

// NewConfig constructs a governance configuration from the supplied delays,
// thresholds, quorum percentage, and execution window.
//
// Parameters:
//   - votingStartDelay: delay from proposal creation until voting opens, in seconds
//   - votingPeriod: duration for which voting remains open, in seconds
//   - votingWeightSmoothingDuration: interval used to smooth delegation weight, in seconds
//   - quorum: required approval percentage of total xGNS supply, from 0 through 100
//   - proposalCreationThreshold: minimum xGNS amount required to create a proposal
//   - executionDelay: delay after voting ends before execution, in seconds
//   - executionWindow: duration after the execution delay during which execution is allowed, in seconds
//
// Returns:
//   - Config: configuration value populated with the supplied governance parameters
func NewConfig(
	votingStartDelay,
	votingPeriod,
	votingWeightSmoothingDuration,
	quorum,
	proposalCreationThreshold,
	executionDelay,
	executionWindow int64,
) Config {
	return Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}
}

// NewConfigPtr constructs a Config and returns a pointer to it. The Config is
// allocated within the governance domain realm, satisfying realm allocation
// checks for callers (such as tests) that require a *Config value.
//
// Parameters:
//   - votingStartDelay: delay from proposal creation until voting opens, in seconds
//   - votingPeriod: duration for which voting remains open, in seconds
//   - votingWeightSmoothingDuration: interval used to smooth delegation weight, in seconds
//   - quorum: required approval percentage of total xGNS supply, from 0 through 100
//   - proposalCreationThreshold: minimum xGNS amount required to create a proposal
//   - executionDelay: delay after voting ends before execution, in seconds
//   - executionWindow: duration after the execution delay during which execution is allowed, in seconds
//
// Returns:
//   - *Config: pointer to a configuration value populated with the supplied governance parameters
func NewConfigPtr(
	votingStartDelay,
	votingPeriod,
	votingWeightSmoothingDuration,
	quorum,
	proposalCreationThreshold,
	executionDelay,
	executionWindow int64,
) *Config {
	c := NewConfig(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
	return &c
}

// NewDefaultConfig returns the governance configuration's built-in defaults:
// one day before voting, seven days of voting, one day of weight smoothing,
// 50% quorum, a 1-billion-xGNS creation threshold, one day execution delay,
// and a 30-day execution window.
//
// Returns:
//   - Config: default governance configuration value
func NewDefaultConfig() Config {
	return Config{
		VotingStartDelay:              86400,         // 1 day - delay before voting starts
		VotingPeriod:                  604800,        // 7 days - duration for collecting votes
		VotingWeightSmoothingDuration: 86400,         // 1 day - period for averaging voting weight
		Quorum:                        50,            // 50% of total xGNS supply required
		ProposalCreationThreshold:     1_000_000_000, // 1 billion xGNS - minimum amount to create proposals
		ExecutionDelay:                86400,         // 1 day - waiting period before execution
		ExecutionWindow:               2592000,       // 30 days - window for executing proposals
	}
}

// NewConfigTree creates an empty BPTree used to index configuration values by
// their encoded int64 version.
//
// Returns:
//   - *bptree.BPTree: empty configuration index tree
func NewConfigTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}
