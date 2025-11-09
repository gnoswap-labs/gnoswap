package governance

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
