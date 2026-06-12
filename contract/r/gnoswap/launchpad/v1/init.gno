package v1

import (
	"gno.land/r/gnoswap/launchpad"
)

func init(cur realm) {
	registerLaunchpadV1(cur)
}

func registerLaunchpadV1(cur realm) {
	launchpad.RegisterInitializer(cross(cur), func(_ int, rlm realm, launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		err := initStoreData(0, rlm, launchpadStore)
		if err != nil {
			panic(err)
		}

		return NewLaunchpadV1(launchpadStore)
	})
}

func initStoreData(_ int, rlm realm, launchpadStore launchpad.ILaunchpadStore) error {
	if !launchpadStore.HasProjectsKey() {
		err := launchpadStore.SetProjects(0, rlm, launchpad.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasProjectTierRewardManagersKey() {
		err := launchpadStore.SetProjectTierRewardManagers(0, rlm, launchpad.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasDepositCounterStoreKey() {
		err := launchpadStore.SetDepositCounter(0, rlm, launchpad.NewCounter())
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasDepositsKey() {
		err := launchpadStore.SetDeposits(0, rlm, launchpad.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	return nil
}
