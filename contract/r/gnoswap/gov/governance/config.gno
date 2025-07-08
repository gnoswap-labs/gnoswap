package governance

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/halt"
)

// Config represents the configuration of the governor contract
// ref: https://docs.gnoswap.io/core-concepts/governance#scope-of-proposals-5
type Config struct {
	// VotingStartDelay is the delay before voting starts after proposal creation (in seconds)
	VotingStartDelay uint64
	// VotingPeriod is the duration during which votes are collected (in seconds)
	VotingPeriod uint64
	// VotingWeightSmoothingDuration is the period over which voting weight is averaged
	// for proposal creation and cancellation threshold calculations (in seconds)
	VotingWeightSmoothingDuration uint64
	// Quorum is the percentage of total GNS supply required for proposal approval
	Quorum uint64
	// ProposalCreationThreshold is the minimum average voting weight required to create a proposal
	ProposalCreationThreshold uint64
	// ExecutionDelay is the waiting period after voting ends before a proposal can be executed (in seconds)
	ExecutionDelay uint64
	// ExecutionWindow is the time window during which an approved proposal can be executed (in seconds)
	ExecutionWindow uint64
}

// ReconfigureByAdmin updates the proposal realted configuration.
// Returns the new configuration version number.
func ReconfigureByAdmin(
	cur realm,
	votingStartDelay uint64,
	votingPeriod uint64,
	votingWeightSmoothingDuration uint64,
	quorum uint64,
	proposalCreationThreshold uint64,
	executionDelay uint64,
	executionWindow uint64,
) uint64 {
	caller := std.PreviousRealm().Address()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	cfg := Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}

	return reconfigure(cur, cfg)
}

// reconfigure updates the Governor's configuration.
// Only governance contract can execute this function via proposal
// Returns the new configuration version number.
func reconfigure(cur realm, cfg Config) uint64 {
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	en.MintAndDistributeGns(cross)

	var prevVersion, newVersion uint64

	// Update proposal states before reconfiguring using middleware pattern
	executeWithStateUpdate(func() {
		prevVersion = governanceState.configCounter

		// Apply reconfiguration using state transition
		transition := ReconfigureTransition(cfg)
		if err := applyTransition(transition); err != nil {
			panic(err)
		}

		newVersion = governanceState.configCounter
	})

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Reconfigure",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"votingStartDelay", formatUint(cfg.VotingStartDelay),
		"votingPeriod", formatUint(cfg.VotingPeriod),
		"votingWeightSmoothingDuration", formatUint(cfg.VotingWeightSmoothingDuration),
		"quorum", formatUint(cfg.Quorum),
		"proposalCreationThreshold", formatUint(cfg.ProposalCreationThreshold),
		"executionDelay", formatUint(cfg.ExecutionDelay),
		"executionPeriod", formatUint(cfg.ExecutionWindow),
		"newConfigVersion", formatUint(newVersion),
		"prevConfigVersion", formatUint(prevVersion),
	)

	return newVersion
}

// GetConfigVersion returns the configuration for a specific version.
// If version is 0, it returns the current configuration.
func GetConfigVersion(version uint64) Config {
	cfg, exists := governanceState.GetConfig(version)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("config version(%d) does not exist", version),
		))
	}

	return cfg
}

// GetLatestConfig returns the latest configuration.
func GetLatestConfig() Config {
	return governanceState.currentConfig
}

// GetLatestConfigVersion returns the latest configuration version.
func GetLatestConfigVersion() uint64 {
	return governanceState.configCounter
}

// GetProposalCreationThreshold returns the current proposal creation threshold.
func GetProposalCreationThreshold() uint64 {
	return governanceState.currentConfig.ProposalCreationThreshold
}
