package v1

import (
	"chain"
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
	// Create new configuration with provided parameters. Constructed via the
	// domain constructor so the Config value is allocated inside the governance
	// domain realm (satisfies the realm allocation check).
	return governance.NewConfig(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
}

// Reconfigure updates governance configuration.
// Only admin or governance contract can call this function.
// Updates all governance parameters and emits a "Reconfigure" event.
func (gv *governanceV1) Reconfigure(
	_ int, rlm realm,
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	// Check if system is halted before proceeding
	halt.AssertIsNotHaltedGovernance()

	prev := rlm.Previous()
	caller := prev.Address()
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
	en.MintAndDistributeGns(cross(rlm))

	// Store previous version for event emission
	previousVersion := gv.getCurrentConfigVersion()

	// Apply the new configuration
	nextVersion := gv.reconfigure(0, rlm, newCfg)

	chain.Emit(
		"Reconfigure",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
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
func (gv *governanceV1) reconfigure(_ int, rlm realm, cfg governance.Config) int64 {
	// Generate next version number
	nextVersion := gv.nextConfigVersion(0, rlm)

	// Store the new configuration with version
	err := gv.setConfig(0, rlm, nextVersion, cfg)
	if err != nil {
		panic("failed to set config: " + err.Error())
	}

	return nextVersion
}
