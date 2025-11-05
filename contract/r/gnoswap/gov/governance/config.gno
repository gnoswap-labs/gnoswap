package governance

import "errors"

// Config represents the configuration of the governor contract
// All parameters in this struct can be modified through governance.
type Config struct {
	// VotingStartDelay is the delay before voting starts after proposal creation (in seconds)
	VotingStartDelay int64
	// VotingPeriod is the duration during which votes are collected (in seconds)
	VotingPeriod int64
	// VotingWeightSmoothingDuration is the period over which voting weight is averaged
	// for proposal creation and cancellation threshold calculations (in seconds)
	VotingWeightSmoothingDuration int64
	// Quorum is the percentage of total GNS supply required for proposal approval
	Quorum int64
	// ProposalCreationThreshold is the minimum average voting weight required to create a proposal
	ProposalCreationThreshold int64
	// ExecutionDelay is the waiting period after voting ends before a proposal can be executed (in seconds)
	ExecutionDelay int64
	// ExecutionWindow is the time window during which an approved proposal can be executed (in seconds)
	ExecutionWindow int64
}

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
