package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
)

// Reconfigure updates governance configuration.
// Only admin or governance contract can call this function.
// Updates all governance parameters and emits a "Reconfigure" event.
func (gv *governanceV1) Reconfigure(
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

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Store previous version for event emission
	previousVersion := gv.getCurrentConfigVersion()

	// Apply the new configuration
	nextVersion, newCfg := gv.reconfigure(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)

	// Emit configuration change event with all parameters
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
func (gv *governanceV1) reconfigure(
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) (int64, governance.Config) {
	// Create new configuration with provided parameters
	cfg := governance.Config{
		VotingStartDelay:              votingStartDelay,
		VotingPeriod:                  votingPeriod,
		VotingWeightSmoothingDuration: votingWeightSmoothingDuration,
		Quorum:                        quorum,
		ProposalCreationThreshold:     proposalCreationThreshold,
		ExecutionDelay:                executionDelay,
		ExecutionWindow:               executionWindow,
	}

	// Validate the new configuration
	assertIsValidConfig(cfg)

	// Generate next version number
	nextVersion := gv.nextConfigVersion()

	// Store the new configuration with version
	err := gv.setConfig(nextVersion, cfg)
	if err != nil {
		panic("failed to set config: " + err.Error())
	}

	return nextVersion, cfg
}
