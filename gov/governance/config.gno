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
		// - config for makefile testing
		// VotingStartDelay:              uint64(10),   // 10s ≈ 5 block
		// VotingPeriod:                  uint64(30),   // 30s ≈ 15 block
		// VotingWeightSmoothingDuration: uint64(10),   // 10s ≈ 5 block
		// Quorum:                        uint64(50),   // 50% of total xGNS supply
		// ProposalCreationThreshold:     uint64(100),  //
		// ExecutionDelay:                uint64(10),   // 10s ≈5 block
		// ExecutionWindow:               uint64(1000), // 500 block

		// XXX: TODO, REMOVE AFTER QA
		// - config for live qa
		VotingStartDelay:              uint64(180),       // 3m
		VotingPeriod:                  uint64(600),       // 10m
		VotingWeightSmoothingDuration: uint64(600),       // 10m
		Quorum:                        uint64(50),        // 50% of total xGNS supply
		ProposalCreationThreshold:     uint64(3_000_000), // 3_000_000
		ExecutionDelay:                uint64(60),        // 1m
		ExecutionWindow:               uint64(300),       // 5m
	}

	// https://docs.gnoswap.io/core-concepts/governance
	// config = Config{
	// 	VotingStartDelay:              uint64(86400),   // 1d
	// 	VotingPeriod:                  uint64(604800),  // 7d
	// 	VotingWeightSmoothingDuration: uint64(86400),   // 1d
	// 	Quorum:                        uint64(50),      // 50% of total xGNS supply
	// 	ProposalCreationThreshold:     uint64(100),     // XXX TO BE CONFIRMED
	// 	ExecutionDelay:                uint64(86400),   // 1d
	// 	ExecutionWindow:               uint64(2592000), // 30d
	// }

	// config version 0 should return the current config
	// therefore we set initial config version to 1
	configVersions[uint64(len(configVersions)+1)] = config
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
	en.MintAndDistributeGns()
	updateProposalsState()

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
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_version", ufmt.Sprintf("%d", newVersion),
		"p_voting_start_delay", ufmt.Sprintf("%d", config.VotingStartDelay),
		"p_voting_period", ufmt.Sprintf("%d", config.VotingPeriod),
		"p_voting_weight_smoothing_duration", ufmt.Sprintf("%d", config.VotingWeightSmoothingDuration),
		"p_quorum", ufmt.Sprintf("%d", config.Quorum),
		"p_proposal_creation_threshold", ufmt.Sprintf("%d", config.ProposalCreationThreshold),
		"p_execution_delay", ufmt.Sprintf("%d", config.ExecutionDelay),
		"p_execution_window", ufmt.Sprintf("%d", config.ExecutionWindow),
	)

	return newVersion
}
