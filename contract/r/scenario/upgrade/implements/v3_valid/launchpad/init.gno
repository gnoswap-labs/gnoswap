package v3

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
		err := launchpadStore.SetProjects(bptree.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasProjectTierRewardManagersKey() {
		err := launchpadStore.SetProjectTierRewardManagers(bptree.NewBPTreeN(16))
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

	if !launchpadStore.HasDepositsKey() {
		err := launchpadStore.SetDeposits(bptree.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	return nil
}
