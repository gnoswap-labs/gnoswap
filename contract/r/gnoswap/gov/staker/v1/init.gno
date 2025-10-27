package v1

import (
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
	if !store.HasDelegationNextIDStoreKey() {
		err := store.SetDelegationNextID(int64(1))
		if err != nil {
			return err
		}
	}

	if !store.HasDelegationsStoreKey() {
		err := store.SetDelegation(0, &staker.Delegation{}) // Initialize with dummy to create the tree
		if err != nil {
			return err
		}
		err = store.RemoveDelegation(0) // Remove the dummy
		if err != nil {
			return err
		}
	}

	// Initialize delegation history
	if !store.HasDelegationHistoryStoreKey() {
		err := store.AddDelegationRecord(&staker.DelegationRecord{}) // Initialize with dummy
		if err != nil {
			return err
		}
		// Clear the dummy record by getting and resetting
		_, err = store.GetDelegationHistory()
		if err != nil {
			return err
		}
	}

	// Initialize user delegations
	if !store.HasUserDelegationsStoreKey() {
		err := store.AddUserDelegation("", "", 0) // Initialize with dummy
		if err != nil {
			return err
		}
		err = store.RemoveUserDelegation("", "", 0) // Remove the dummy
		if err != nil {
			return err
		}
	}

	// Initialize delegation snapshots
	if !store.HasDelegationSnapshotsStoreKey() {
		err := store.SetDelegationSnapshot(0, staker.DelegationSnapshot{})
		if err != nil {
			return err
		}
		// The snapshot tree is should be initialized
	}

	return nil
}
