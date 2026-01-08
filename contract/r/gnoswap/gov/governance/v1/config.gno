package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
)

// makeConfig creates a new governance configuration.
func makeConfig(
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) governance.Config {
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

	return cfg
}

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

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidSmoothingPeriod(votingWeightSmoothingDuration)

	// Create and validate new configuration
	newCfg := makeConfig(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)

	currentTime := time.Now().Unix()

	if err := newCfg.IsValid(currentTime); err != nil {
		panic(makeErrorWithDetails(errInvalidConfiguration, err.Error()))
	}

	// Mint and distribute GNS tokens as part of the process
	en.MintAndDistributeGns(cross)

	// Store previous version for event emission
	previousVersion := gv.getCurrentConfigVersion()

	// Apply the new configuration
	nextVersion := gv.reconfigure(newCfg)

	chain.Emit(
		"Reconfigure",
		"prevAddr", caller.String(),
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

// reconfigure stores the validated configuration with incremented version number.
func (gv *governanceV1) reconfigure(cfg governance.Config) int64 {
	// Generate next version number
	nextVersion := gv.nextConfigVersion()

	// Store the new configuration with version
	err := gv.setConfig(nextVersion, cfg)
	if err != nil {
		panic("failed to set config: " + err.Error())
	}

	return nextVersion
}
