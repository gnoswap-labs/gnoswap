package governance

import (
	"std"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	config         Config
	configVersions = make(map[uint64]Config)
)

func init() {
	// value for testing case from @notJoon
	config = Config{
		VotingStartDelay:              uint64(100),
		VotingPeriod:                  uint64(1000),
		VotingWeightSmoothingDuration: uint64(100),
		Quorum:                        uint64(500),
		ProposalCreationThreshold:     uint64(100),
		ExecutionDelay:                uint64(100),
		ExecutionWindow:               uint64(1000),
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
func Reconfigure(newConfigJSON string) uint64 {
	prev := std.PrevRealm().PkgPath()
	if !(prev == "" || (prev == consts.GOV_GOVERNANCE_PATH)) {
		panic(
			ufmt.Sprintf(
				"Reconfigure can only be called by the governance contract, but was called by orig(%s), prev(%s), curr(%s)",
				std.GetOrigCaller().String(), prev, std.CurrentRealm().PkgPath(),
			),
		)
	}

	newConfigNode, err := json.Unmarshal([]byte(newConfigJSON))
	if err != nil {
		panic("invalid confiquration JSON: " + err.Error())
	}

	config = parseConfig(newConfigNode)

	newVersion := uint64(len(configVersions) + 1)
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

// parseConfig converts a JSON Node representing a config into a Config struct.
// The input JSON object should have the following structure:
//
//	{
//	  "votingStartDelay": 100,
//	  "votingPeriod": 1000,
//	  "votingWeightSmoothingDuration": 100,
//	  "quorum": "500",
//	  "proposalCreationThreshold": "100",
//	  "executionDelay": 100,
//	  "executionWindow": 1000
//	}
//
// Returns a Config struct and an error if parsing fails.
func parseConfig(node *json.Node) Config {
	if !node.IsObject() {
		panic("config must be an object")
	}

	var config Config

	config.VotingStartDelay = parseUint64Field(node, "votingStartDelay")
	config.VotingPeriod = parseUint64Field(node, "votingPeriod")
	config.VotingWeightSmoothingDuration = parseUint64Field(node, "votingWeightSmoothingDuration")
	config.Quorum = parseUint64Field(node, "quorum")
	config.ProposalCreationThreshold = parseUint64Field(node, "proposalCreationThreshold")
	config.ExecutionDelay = parseUint64Field(node, "executionDelay")
	config.ExecutionWindow = parseUint64Field(node, "executionWindow")

	return config
}
