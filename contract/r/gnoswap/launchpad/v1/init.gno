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

	// TODO: consider map — Get/Set only, no Iterate, N<100.
	// persistent benchmark (N=100): BPTree32 Get 2.70M vs Map Get 0.96M (2.8x), Set 3.36M vs 2.11M (1.6x)
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

	// TODO: consider NewBPTreeN(64) — Get/Set, N=1k~10k.
	// persistent benchmark (N=1000): BPTree64 Get -4%, Set -3.4% vs BPTree32
	if !launchpadStore.HasDepositsKey() {
		err := launchpadStore.SetDeposits(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	return nil
}
