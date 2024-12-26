package governance

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
)

var (
	config         Config
	// configVersions = make(map[uint64]Config)
	configVersions = avl.NewTree() // version -> Config
)

func init() {
	// https: //docs.gnoswap.io/core-concepts/governance
	config = Config{
		VotingStartDelay:              uint64(86400),         // 1d
		VotingPeriod:                  uint64(604800),        // 7d
		VotingWeightSmoothingDuration: uint64(86400),         // 1d
		Quorum:                        uint64(50),            // 50% of total xGNS supply
		ProposalCreationThreshold:     uint64(1_000_000_000), // 1_000_000_000
		ExecutionDelay:                uint64(86400),         // 1d
		ExecutionWindow:               uint64(2592000),       // 30d
	}

	// config version 0 should return the current config
	// therefore we set initial config version to 1
	setConfigVersion(1, config)
}

func setConfigVersion(v uint64, cfg Config) {
	configVersions.Set(strconv.Itoa(int(v)), cfg)
}

func getConfigByVersion(v uint64) (Config, bool) {
	value, exists := configVersions.Get(strconv.Itoa(int(v)))
	if !exists {
		return Config{}, false
	}
	return value.(Config), true
}

func getLatestVersion() uint64 {
	var maxVersion uint64
	configVersions.ReverseIterate("", "", func(key string, value interface{}) bool {
		version, _ := strconv.ParseUint(key, 10, 64)
		maxVersion = version
		return true
	})
	return maxVersion
}

// ReconfigureByAdmin updates the proposal realted configuration.
// Returns the new configuration version number.
func ReconfigureByAdmin(
	votingStartDelay uint64,
	votingPeriod uint64,
	votingWeightSmoothingDuration uint64,
	quorum uint64,
	proposalCreationThreshold uint64,
	executionDelay uint64,
	executionWindow uint64,
) uint64 {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	newVersion := getLatestVersion() + 1

	config = Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}
	setConfigVersion(newVersion, config)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"ReconfigureByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"votingStartDelay", ufmt.Sprintf("%d", config.VotingStartDelay),
		"votingPeriod", ufmt.Sprintf("%d", config.VotingPeriod),
		"votingWeightSmoothingDuration", ufmt.Sprintf("%d", config.VotingWeightSmoothingDuration),
		"quorum", ufmt.Sprintf("%d", config.Quorum),
		"proposalCreationThreshold", ufmt.Sprintf("%d", config.ProposalCreationThreshold),
		"executionDelay", ufmt.Sprintf("%d", config.ExecutionDelay),
		"executionWindow", ufmt.Sprintf("%d", config.ExecutionWindow),
		"internal_newVersion", ufmt.Sprintf("%d", newVersion),
	)

	return newVersion
}

// reconfigure updates the Governor's configuration.
// Only governance contract can execute this function via proposal
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

	newVersion := getLatestVersion() + 1

	config = Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}
	setConfigVersion(newVersion, config)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Reconfigure",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"votingStartDelay", ufmt.Sprintf("%d", config.VotingStartDelay),
		"votingPeriod", ufmt.Sprintf("%d", config.VotingPeriod),
		"votingWeightSmoothingDuration", ufmt.Sprintf("%d", config.VotingWeightSmoothingDuration),
		"quorum", ufmt.Sprintf("%d", config.Quorum),
		"proposalCreationThreshold", ufmt.Sprintf("%d", config.ProposalCreationThreshold),
		"executionDelay", ufmt.Sprintf("%d", config.ExecutionDelay),
		"executionWindow", ufmt.Sprintf("%d", config.ExecutionWindow),
		"internal_newVersion", ufmt.Sprintf("%d", newVersion),
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

	cfg, exists := getConfigByVersion(version)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("config version(%d) does not exist", version),
		))
	}

	return cfg
}

// GetLatestConfig() returns the latest configuration.
func GetLatestConfig() Config {
	return config
}

// GetLatestConfigVersion() returns the latest configuration version.
func GetLatestConfigVersion() uint64 {
	return getLatestVersion()
}

// GetProposalCreationThreshold() returns the current proposal creation threshold.
func GetProposalCreationThreshold() uint64 {
	return config.ProposalCreationThreshold
}
