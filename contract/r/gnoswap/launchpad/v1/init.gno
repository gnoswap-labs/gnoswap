package launchpad

import "gno.land/r/gnoswap/launchpad"

// init registers the v1 launchpad implementation when the realm is initialized.
//
// Parameters:
//   - cur: current realm context supplied by the runtime during package initialization.
func init(cur realm) {
	registerLaunchpadV1(cur)
}

// registerLaunchpadV1 registers the v1 initializer with the launchpad upgrade system.
//
// Parameters:
//   - cur: current realm context used to cross into the launchpad registry.
func registerLaunchpadV1(cur realm) {
	launchpad.RegisterInitializer(cross(cur), func(_ int, rlm realm, launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		err := initStoreData(0, rlm, launchpadStore)
		if err != nil {
			panic(err)
		}

		return NewLaunchpadV1(launchpadStore)
	})
}

// initStoreData creates any missing launchpad state trees, counter, and total-stake entry.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated current realm context used by the store setters.
//   - launchpadStore: storage interface whose missing keys are initialized.
//
// Returns:
//   - err: nil when every missing key is initialized or already present; non-nil from the first failed store write.
func initStoreData(_ int, rlm realm, launchpadStore launchpad.ILaunchpadStore) error {
	if !launchpadStore.HasProjectsKey() {
		err := launchpadStore.SetProjects(0, rlm, launchpad.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	if !launchpadStore.HasProjectRecipientsKey() {
		err := launchpadStore.SetProjectRecipients(0, rlm, launchpad.NewBPTreeN(16))
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

	if !launchpadStore.HasTotalGNSStakedAmountKey() {
		err := launchpadStore.SetTotalGNSStakedAmount(0, rlm, 0)
		if err != nil {
			return err
		}
	}

	return nil
}
