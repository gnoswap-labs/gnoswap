package v1

import (
	"strconv"

	bptree "gno.land/p/nt/bptree/v0"
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
		configs := bptree.NewBPTree32()
		nextConfigVersion := governanceStore.GetConfigCounter().Next()

		configs.Set(formatConfigKey(nextConfigVersion), defaultConfig)

		err := governanceStore.SetConfigs(configs)
		if err != nil {
			return err
		}
	}

	// NOTE: proposals — Iterate used, N grows over time. BPTree32 OK (paginated reads, N<1000 near-term).
	if !governanceStore.HasProposalsStoreKey() {
		err := governanceStore.SetProposals(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	// TODO: consider NewBPTreeN(64) (RULE 4) — Iterate used (voter enumeration).
	// Outer N=proposals (hundreds+), inner voter trees N=hundreds~thousands per popular proposal.
	// Benchmark (N=1000): BPT64 Get -3.4%, Set -3.4%.
	if !governanceStore.HasProposalUserVotingInfosStoreKey() {
		err := governanceStore.SetProposalUserVotingInfos(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	// TODO: consider map (RULE 1) — Get/Set only, no Iterate in production.
	// Benchmark (N=100): BPT32 Get 2.70M vs Map 0.96M (2.8x). Determinism: no iteration.
	if !governanceStore.HasUserProposalsStoreKey() {
		err := governanceStore.SetUserProposals(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	return nil
}

func formatConfigKey(version int64) string {
	return strconv.FormatInt(version, 10)
}
