package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/launchpad"
)

func init() {
	registerLaunchpadV1()
}

func registerLaunchpadV1() {
	launchpad.RegisterInitializer(cross, func(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		initStoreData(launchpadStore)

		return NewLaunchpadV1(launchpadStore)
	})
}

func initStoreData(launchpadStore launchpad.ILaunchpadStore) {
	if !launchpadStore.HasProjectsKey() {
		err := launchpadStore.SetProjects(avl.NewTree())
		if err != nil {
			panic(err)
		}
	}

	if !launchpadStore.HasProjectTierRewardManagersKey() {
		err := launchpadStore.SetProjectTierRewardManagers(avl.NewTree())
		if err != nil {
			panic(err)
		}
	}

	if !launchpadStore.HasDepositCounterKey() {
		err := launchpadStore.SetDepositCounter(NewCounter())
		if err != nil {
			panic(err)
		}
	}

	if !launchpadStore.HasDepositsKey() {
		err := launchpadStore.SetDeposits(avl.NewTree())
		if err != nil {
			panic(err)
		}
	}
}
