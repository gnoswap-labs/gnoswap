package v1

import (
	"strconv"

	"gno.land/r/gnoswap/gov/governance"
)

func init(cur realm) {
	registerGovernanceV1(cur)
}

func registerGovernanceV1(cur realm) {
	governance.RegisterInitializer(cross(cur), func(_ int, rlm realm, governanceStore governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
		// `rlm` here is the governance proxy realm threaded in by
		// governance.RegisterInitializer. Per-version store bootstrap
		// writes therefore pass the proxy's KV-store ACL.
		err := initStoreData(0, rlm, governanceStore)
		if err != nil {
			panic(err)
		}

		return NewGovernanceV1(governanceStore, stakerAccessor)
	})
}

func initStoreData(_ int, rlm realm, governanceStore governance.IGovernanceStore) error {
	// Initialize counters if not already set
	if !governanceStore.HasConfigCounterStoreKey() {
		err := governanceStore.SetConfigCounter(0, rlm, governance.NewCounter())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalCounterStoreKey() {
		err := governanceStore.SetProposalCounter(0, rlm, governance.NewCounter())
		if err != nil {
			return err
		}
	}

	// Initialize Configs with default configuration if not already set
	if !governanceStore.HasConfigsStoreKey() {
		configs := governance.NewConfigTree()
		counter := governanceStore.GetConfigCounter()
		nextConfigVersion := counter.Next()

		configs.Set(formatConfigKey(nextConfigVersion), governance.NewDefaultConfig())

		err := governanceStore.SetConfigs(0, rlm, configs)
		if err != nil {
			return err
		}
		// Persist the mutated counter so the bumped version survives the
		// boundary into the proxy's KV store.
		if err := governanceStore.SetConfigCounter(0, rlm, counter); err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalsStoreKey() {
		err := governanceStore.SetProposals(0, rlm, governance.NewProposalTree())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasProposalUserVotingInfosStoreKey() {
		err := governanceStore.SetProposalUserVotingInfos(0, rlm, governance.NewProposalUserVotingInfoTree())
		if err != nil {
			return err
		}
	}

	if !governanceStore.HasUserProposalsStoreKey() {
		err := governanceStore.SetUserProposals(0, rlm, governance.NewUserProposalTree())
		if err != nil {
			return err
		}
	}

	return nil
}

func formatConfigKey(version int64) string {
	return strconv.FormatInt(version, 10)
}
