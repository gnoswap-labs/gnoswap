package governance

import (
	"std"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
)

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

// Reconfigure updates governance configuration.
// Only admin or governance contract can call this function.
// Updates all governance parameters and emits a "Reconfigure" event.
func Reconfigure(
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
	halt.AssertIsNotHaltedGovernance()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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
	previousRealm := std.PreviousRealm()
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

// reconfigure updates the Governor's configuration.
// Creates new configuration and stores it with incremented version number.
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
