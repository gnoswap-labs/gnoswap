package governance

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"
)

var (
	config         Config
	configVersions = make(map[uint64]Config)
)

func init() {
	// value for testing case from @notJoon
	config = Config{
		// XXX: TODO, REMOVE AFTER QA
		// - config for testcase
		VotingStartDelay:              uint64(10),   // 10s ≈ 5 block
		VotingPeriod:                  uint64(30),   // 30s ≈ 15 block
		VotingWeightSmoothingDuration: uint64(10),   // 10s ≈ 5 block
		Quorum:                        uint64(50),   // 50% of total xGNS supply
		ProposalCreationThreshold:     uint64(100),  //
		ExecutionDelay:                uint64(10),   // 10s ≈ 5 block
		ExecutionWindow:               uint64(1000), // 500 block

		// XXX: TODO, REMOVE AFTER QA
		// - config for live qa
		// VotingStartDelay:              uint64(180),           // 3m
		// VotingPeriod:                  uint64(600),           // 10m
		// VotingWeightSmoothingDuration: uint64(600),           // 10m
		// Quorum:                        uint64(50),            // 50% of total xGNS supply
		// ProposalCreationThreshold:     uint64(1_000_000_000), // 1_000_000_000
		// ExecutionDelay:                uint64(60),            // 1m
		// ExecutionWindow:               uint64(3600),          // 1h
	}

	// https://docs.gnoswap.io/core-concepts/governance
	// config = Config{
	// 	VotingStartDelay:              uint64(86400),         // 1d
	// 	VotingPeriod:                  uint64(604800),        // 7d
	// 	VotingWeightSmoothingDuration: uint64(86400),         // 1d
	// 	Quorum:                        uint64(50),            // 50% of total xGNS supply
	// 	ProposalCreationThreshold:     uint64(1_000_000_000), // 1_000_000_000
	// 	ExecutionDelay:                uint64(86400),         // 1d
	// 	ExecutionWindow:               uint64(2592000),       // 30d
	// }

	// config version 0 should return the current config
	// therefore we set initial config version to 1
	configVersions[uint64(len(configVersions)+1)] = config
}

// Reconfigure updates the Governor's configuration.
// This function can only be called by admin
// Returns the new configuration version number.
func Reconfigure(
	votingStartDelay uint64,
	votingPeriod uint64,
	votingWeightSmoothingDuration uint64,
	quorum uint64,
	proposalCreationThreshold uint64,
	executionDelay uint64,
	executionWindow uint64,
) uint64 {
	assertUserCall()

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic("Reconfigure can only be called by the admin")
	}

	return reconfigure(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
}

// reconfigure updates the Governor's configuration.
// This function can only be called by the Governor itself (via a proposal).
// Returns the new configuration version number.
func reconfigure(
	votingStartDelay uint64,
	votingPeriod uint64,
	votingWeightSmoothingDuration uint64,
	quorum uint64,
	proposalCreationThreshold uint64,
	executionDelay uint64,
	executionWindow uint64,
) uint64 {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	newVersion := uint64(len(configVersions) + 1)

	config = Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}
	configVersions[newVersion] = config

	std.Emit(
		"Reconfigured",
		"m_prevRealm", prevRealm(),
		"p_voting_start_delay", ufmt.Sprintf("%d", config.VotingStartDelay),
		"p_voting_period", ufmt.Sprintf("%d", config.VotingPeriod),
		"p_voting_weight_smoothing_duration", ufmt.Sprintf("%d", config.VotingWeightSmoothingDuration),
		"p_quorum", ufmt.Sprintf("%d", config.Quorum),
		"p_proposal_creation_threshold", ufmt.Sprintf("%d", config.ProposalCreationThreshold),
		"p_execution_delay", ufmt.Sprintf("%d", config.ExecutionDelay),
		"p_execution_window", ufmt.Sprintf("%d", config.ExecutionWindow),
		"newVersion", ufmt.Sprintf("%d", newVersion),
	)

	return newVersion
}

// GetConfigVersion returns the configuration for a specific version.
// If version is 0, it returns the current configuration.
func GetConfigVersion(version uint64) Config {
	en.MintAndDistributeGns()
	// updateProposalsState() // do not call this function here, it will cause a init loop in updateProposal()

	if version == 0 {
		return config
	}

	configValue, exist := configVersions[version]
	if !exist {
		panic("CONFIG DOES_NOT_EXIST")
	}

	return configValue
}

// GetLatestConfig() returns the latest configuration.
func GetLatestConfig() Config {
	return config
}

// GetLatestConfigVersion() returns the latest configuration version.
func GetLatestConfigVersion() uint64 {
	return uint64(len(configVersions))
}

// GetProposalCreationThreshold() returns the current proposal creation threshold.
func GetProposalCreationThreshold() uint64 {
	return config.ProposalCreationThreshold
}
