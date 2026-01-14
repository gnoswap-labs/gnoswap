package v2

import (
	"strconv"

	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/governance"
)

var defaultConfig = governance.Config{
	VotingStartDelay:              86400,         // 1 day - delay before voting starts
	VotingPeriod:                  604800,        // 7 days - duration for collecting votes
	VotingWeightSmoothingDuration: 86400,         // 1 day - period for averaging voting weight
	Quorum:                        50,            // 50% of total xGNS supply required
	ProposalCreationThreshold:     1_000_000_000, // 1 billion - minimum balance to create proposals
	ExecutionDelay:                86400,         // 1 day - waiting period before execution
	ExecutionWindow:               2592000,       // 30 days - window for executing proposals
}

func init() {
	registerGovernanceV1()
}

func registerGovernanceV1() {
	governance.RegisterInitializer(cross, func(governanceStore governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
		err := initStoreData(governanceStore)
		if err != nil {
			panic(err)
		}

		return NewGovernanceV1(governanceStore, stakerAccessor)
	})
}

func initStoreData(governanceStore governance.IGovernanceStore) error {
	// Initialize counters if not already set
	if !governanceStore.HasConfigCounterStoreKey() {
		err := governanceStore.SetConfigCounter(governance.NewCounter())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalCounterStoreKey() {
		err := governanceStore.SetProposalCounter(governance.NewCounter())
		if err != nil {
			return err
		}
	}

	// Initialize Configs with default configuration if not already set
	if !governanceStore.HasConfigsStoreKey() {
		configs := avl.NewTree()
		nextConfigVersion := governanceStore.GetConfigCounter().Next()

		configs.Set(formatConfigKey(nextConfigVersion), defaultConfig)

		err := governanceStore.SetConfigs(configs)
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalsStoreKey() {
		err := governanceStore.SetProposals(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalUserVotingInfosStoreKey() {
		err := governanceStore.SetProposalUserVotingInfos(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasUserProposalsStoreKey() {
		err := governanceStore.SetUserProposals(avl.NewTree())
		if err != nil {
			return err
		}
	}

	return nil
}

func formatConfigKey(version int64) string {
	return strconv.FormatInt(version, 10)
}
