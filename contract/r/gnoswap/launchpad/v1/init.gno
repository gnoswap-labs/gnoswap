package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
	"gno.land/r/gnoswap/launchpad"
)

func init() {
	registerLaunchpadV1()
}

func registerLaunchpadV1() {
	launchpad.RegisterInitializer(cross, func(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		err := initStoreData(launchpadStore)
		if err != nil {
			panic(err)
		}

		return NewLaunchpadV1(launchpadStore)
	})
}

func initStoreData(launchpadStore launchpad.ILaunchpadStore) error {
	if !launchpadStore.HasProjectsKey() {
		err := launchpadStore.SetProjects(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	// TODO: consider map (RULE 1) — Get/Set only, no Iterate, N<100.
	// Benchmark (N=100): BPT32 Get 2.70M vs Map 0.96M (2.8x). Determinism: no iteration in production.
	if !launchpadStore.HasProjectTierRewardManagersKey() {
		err := launchpadStore.SetProjectTierRewardManagers(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasDepositCounterStoreKey() {
		err := launchpadStore.SetDepositCounter(launchpad.NewCounter())
		if err != nil {
			return err
		}
	}

	// TODO: consider NewBPTreeN(64) (RULE 4) — Get/Set, N=1k~10k.
	// Benchmark (N=1000): BPT64 Get -3.4%, Set -3.4%. BPT128 is WORSE.
	if !launchpadStore.HasDepositsKey() {
		err := launchpadStore.SetDeposits(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	return nil
}
