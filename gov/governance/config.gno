package governance

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"
)

var (
	config         Config
	configVersions = make(map[uint64]Config)
)

func init() {
	// value for testing case from @notJoon
	config = Config{
		VotingStartDelay:              uint64(100),  // 50 block
		VotingPeriod:                  uint64(1000), // 500 block
		VotingWeightSmoothingDuration: uint64(100),  // 50 block
		Quorum:                        uint64(500),  // 250 block
		ProposalCreationThreshold:     uint64(100),  // 50 block
		ExecutionDelay:                uint64(100),  // 50 block
		ExecutionWindow:               uint64(1000), // 500 block
	}

	// https://docs.gnoswap.io/core-concepts/governance
	// config = Config{
	// 	VotingStartDelay:              86400,   // 1d
	// 	VotingPeriod:                  604800,  // 7d
	// 	VotingWeightSmoothingDuration: 86400,   // 1d
	// 	Quorum:                        500,     // XXX TO BE CONFIRMED
	// 	ProposalCreationThreshold:     100,     // XXX TO BE CONFIRMED
	// 	ExecutionDelay:                86400,   // 1d
	// 	ExecutionWindow:        2592000, // 30d
	// }

	// config version 0 should return the current config
	// therefore we set initial config version to 1
	configVersions[uint64(len(configVersions)+1)] = config
}

// GetConfigVersion returns the configuration for a specific version.
// If version is 0, it returns the current configuration.
func GetConfigVersion(version uint64) Config {
	if version == 0 {
		return config
	}

	configValue, exist := configVersions[version]
	if !exist {
		panic("CONFIG DOES_NOT_EXIST")
	}

	return configValue
}

// Reconfigure updates the Governor's configuration.
// This function can only be called by the Governor itself (via a proposal).
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
	common.IsHalted()

	prev := std.PrevRealm().PkgPath()
	if !(prev == "" || (prev == consts.GOV_GOVERNANCE_PATH)) {
		panic(
			ufmt.Sprintf(
				"Reconfigure can only be called by the governance contract, but was called by orig(%s), prev(%s), curr(%s)",
				std.GetOrigCaller().String(), prev, std.CurrentRealm().PkgPath(),
			),
		)
	}

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
		"version", ufmt.Sprintf("%d", newVersion),
		"voting_start_delay", ufmt.Sprintf("%d", config.VotingStartDelay),
		"voting_period", ufmt.Sprintf("%d", config.VotingPeriod),
		"voting_weight_smoothing_duration", ufmt.Sprintf("%d", config.VotingWeightSmoothingDuration),
		"quorum", ufmt.Sprintf("%d", config.Quorum),
		"proposal_creation_threshold", ufmt.Sprintf("%d", config.ProposalCreationThreshold),
		"execution_delay", ufmt.Sprintf("%d", config.ExecutionDelay),
		"execution_window", ufmt.Sprintf("%d", config.ExecutionWindow),
	)

	return newVersion
}
