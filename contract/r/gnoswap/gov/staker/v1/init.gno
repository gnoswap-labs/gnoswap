package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/staker"
)

func init() {
	registerGovStakerV1()
}

func registerGovStakerV1() {
	staker.RegisterInitializer(cross, func(store staker.IGovStakerStore) staker.IGovStaker {
		err := initStoreData(store)
		if err != nil {
			panic(err)
		}

		return NewGovStakerV1(store)
	})
}

func initStoreData(store staker.IGovStakerStore) error {
	// Initialize basic configuration
	if !store.HasUnDelegationLockupPeriodStoreKey() {
		err := store.SetUnDelegationLockupPeriod(int64(86400)) // 1 day default (24 * 60 * 60)
		if err != nil {
			return err
		}
	}

	if !store.HasEmissionRewardBalanceStoreKey() {
		err := store.SetEmissionRewardBalance(int64(0))
		if err != nil {
			return err
		}
	}

	if !store.HasTotalDelegatedAmountStoreKey() {
		err := store.SetTotalDelegatedAmount(int64(0))
		if err != nil {
			return err
		}
	}

	if !store.HasTotalLockedAmountStoreKey() {
		err := store.SetTotalLockedAmount(int64(0))
		if err != nil {
			return err
		}
	}

	// Initialize delegation management
	if !store.HasDelegationCounterStoreKey() {
		err := store.SetDelegationCounter(staker.NewCounter())
		if err != nil {
			return err
		}
	}

	// Initialize delegation snapshots
	if !store.HasDelegationSnapshotStoreKey() {
		err := store.SetDelegationSnapshot(make(staker.DelegationSnapshot, 0))
		if err != nil {
			return err
		}
	}

	if !store.HasDelegationsStoreKey() {
		err := store.SetDelegations(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !store.HasDelegationHistoryStoreKey() {
		err := store.SetDelegationHistory(make([]*staker.DelegationRecord, 0))
		if err != nil {
			return err
		}
	}

	if !store.HasUserDelegationsStoreKey() {
		err := store.SetUserDelegations(make(map[string]map[string][]int64))
		if err != nil {
			return err
		}
	}

	// Initialize EmissionRewardManager
	if !store.HasEmissionRewardManagerStoreKey() {
		emissionRewardManager := staker.NewEmissionRewardManager()
		err := store.SetEmissionRewardManager(emissionRewardManager)
		if err != nil {
			return err
		}
	}

	// Initialize ProtocolFeeRewardManager
	if !store.HasProtocolFeeRewardManagerStoreKey() {
		protocolFeeRewardManager := staker.NewProtocolFeeRewardManager()
		err := store.SetProtocolFeeRewardManager(protocolFeeRewardManager)
		if err != nil {
			return err
		}
	}

	// Initialize LaunchpadProjectDeposits
	if !store.HasLaunchpadProjectDepositsStoreKey() {
		launchpadDeposits := staker.NewLaunchpadProjectDeposits()
		err := store.SetLaunchpadProjectDeposits(launchpadDeposits)
		if err != nil {
			return err
		}
	}

	// Initialize DelegationManager
	if !store.HasDelegationManagerStoreKey() {
		delegationManager := staker.NewDelegationManager()
		err := store.SetDelegationManager(delegationManager)
		if err != nil {
			return err
		}
	}

	return nil
}
