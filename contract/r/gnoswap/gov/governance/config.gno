package governance

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/halt"
)

// Config represents the configuration of the governor contract
// ref: https://docs.gnoswap.io/core-concepts/governance#scope-of-proposals-5
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

// ReconfigureByAdmin updates the governance configuration by admin privileges.
// This function allows administrative updates to governance parameters without going through proposal process.
// 
// Parameters:
//   - cur: realm context (for cross-realm calls)
//   - votingStartDelay: delay before voting starts (seconds)
//   - votingPeriod: duration for collecting votes (seconds)
//   - votingWeightSmoothingDuration: period for averaging voting weight (seconds)
//   - quorum: percentage of total supply required for approval
//   - proposalCreationThreshold: minimum voting weight to create proposals
//   - executionDelay: waiting period before execution (seconds)
//   - executionWindow: time window for execution (seconds)
//
// Returns:
//   - int64: new configuration version number
//
// Panics:
//   - if system is halted
//   - if caller is not admin
func ReconfigureByAdmin(
	cur realm,
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) int64 {
	// Check if system is halted before proceeding
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	// Get caller information and verify admin privileges
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Store previous version for event emission
	previousVersion := getCurrentConfigVersion()
	
	// Apply the new configuration
	nextVersion, newCfg := reconfigure(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)

	// Emit configuration change event with all parameters
	std.Emit(
		"Reconfigure",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"votingStartDelay", formatInt(newCfg.VotingStartDelay),
		"votingPeriod", formatInt(newCfg.VotingPeriod),
		"votingWeightSmoothingDuration", formatInt(newCfg.VotingWeightSmoothingDuration),
		"quorum", formatInt(newCfg.Quorum),
		"proposalCreationThreshold", formatInt(newCfg.ProposalCreationThreshold),
		"executionDelay", formatInt(newCfg.ExecutionDelay),
		"executionPeriod", formatInt(newCfg.ExecutionWindow),
		"newConfigVersion", formatInt(nextVersion),
		"prevConfigVersion", formatInt(previousVersion),
	)

	return nextVersion
}

// ReconfigureByGovernance updates the governance configuration through governance proposal process.
// This function allows configuration updates through democratic voting process.
//
// Parameters:
//   - cur: realm context (for cross-realm calls)
//   - votingStartDelay: delay before voting starts (seconds)
//   - votingPeriod: duration for collecting votes (seconds)
//   - votingWeightSmoothingDuration: period for averaging voting weight (seconds)
//   - quorum: percentage of total supply required for approval
//   - proposalCreationThreshold: minimum voting weight to create proposals
//   - executionDelay: waiting period before execution (seconds)
//   - executionWindow: time window for execution (seconds)
//
// Returns:
//   - int64: new configuration version number
//
// Panics:
//   - if system is halted
//   - if caller is not governance contract
func ReconfigureByGovernance(
	cur realm,
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) int64 {
	// Check if system is halted before proceeding
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	// Get caller information and verify governance privileges
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Store previous version for event emission
	previousVersion := getCurrentConfigVersion()
	
	// Apply the new configuration
	nextVersion, newCfg := reconfigure(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)

	// Emit configuration change event with all parameters
	std.Emit(
		"Reconfigure",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"votingStartDelay", formatInt(newCfg.VotingStartDelay),
		"votingPeriod", formatInt(newCfg.VotingPeriod),
		"votingWeightSmoothingDuration", formatInt(newCfg.VotingWeightSmoothingDuration),
		"quorum", formatInt(newCfg.Quorum),
		"proposalCreationThreshold", formatInt(newCfg.ProposalCreationThreshold),
		"executionDelay", formatInt(newCfg.ExecutionDelay),
		"executionPeriod", formatInt(newCfg.ExecutionWindow),
		"newConfigVersion", formatInt(nextVersion),
		"prevConfigVersion", formatInt(previousVersion),
	)

	return nextVersion
}

// reconfigure is the internal function that updates the Governor's configuration.
// This function creates a new configuration and stores it with an incremented version number.
//
// Parameters:
//   - votingStartDelay: delay before voting starts (seconds)
//   - votingPeriod: duration for collecting votes (seconds)
//   - votingWeightSmoothingDuration: period for averaging voting weight (seconds)
//   - quorum: percentage of total supply required for approval
//   - proposalCreationThreshold: minimum voting weight to create proposals
//   - executionDelay: waiting period before execution (seconds)
//   - executionWindow: time window for execution (seconds)
//
// Returns:
//   - int64: new configuration version number
//   - Config: the newly created configuration
func reconfigure(
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) (int64, Config) {	
	// Create new configuration with provided parameters
	cfg := Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}
	
	// Generate next version number
	nextVersion := nextConfigVersion()

	// Store the new configuration with version
	setConfig(nextVersion, cfg)

	return nextVersion, cfg
}
