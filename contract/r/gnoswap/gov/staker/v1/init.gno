package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

func init(cur realm) {
	registerGovStakerV1(cur)
}

func registerGovStakerV1(cur realm) {
	staker.RegisterInitializer(cross(cur), func(_ int, rlm realm, store staker.IGovStakerStore) staker.IGovStaker {
		// `rlm` here is the gov/staker proxy realm threaded in by
		// staker.RegisterInitializer. Per-version store bootstrap writes
		// therefore pass the proxy's KV-store ACL.
		err := initStoreData(0, rlm, store)
		if err != nil {
			panic(err)
		}

		return NewGovStakerV1(store)
	})
}

func initStoreData(_ int, rlm realm, store staker.IGovStakerStore) error {
	// Initialize basic configuration
	if !store.HasUnDelegationLockupPeriodStoreKey() {
		err := store.SetUnDelegationLockupPeriod(0, rlm, int64(7*24*60*60)) // 7 days default
		if err != nil {
			return err
		}
	}

	if !store.HasTotalDelegatedAmountStoreKey() {
		err := store.SetTotalDelegatedAmount(0, rlm, int64(0))
		if err != nil {
			return err
		}
	}

	if !store.HasTotalLockedAmountStoreKey() {
		err := store.SetTotalLockedAmount(0, rlm, int64(0))
		if err != nil {
			return err
		}
	}

	// Initialize delegation management
	if !store.HasDelegationCounterStoreKey() {
		err := store.SetDelegationCounter(0, rlm, staker.NewCounter())
		if err != nil {
			return err
		}
	}

	if !store.HasDelegationsStoreKey() {
		err := store.SetDelegations(0, rlm, staker.NewDelegationTree())
		if err != nil {
			return err
		}
	}

	// Initialize total delegation history (timestamp -> int64)
	if !store.HasTotalDelegationHistoryStoreKey() {
		err := store.SetTotalDelegationHistory(0, rlm, staker.NewUintTree())
		if err != nil {
			return err
		}
	}

	// Initialize user delegation history (address -> *UintTree[timestamp -> int64])
	if !store.HasUserDelegationHistoryStoreKey() {
		err := store.SetUserDelegationHistory(0, rlm, staker.NewUserDelegationTree())
		if err != nil {
			return err
		}
	}

	// Initialize EmissionRewardManager
	if !store.HasEmissionRewardManagerStoreKey() {
		emissionRewardManager := staker.NewEmissionRewardManager()
		err := store.SetEmissionRewardManager(0, rlm, emissionRewardManager)
		if err != nil {
			return err
		}
	}

	// Initialize ProtocolFeeRewardManager
	if !store.HasProtocolFeeRewardManagerStoreKey() {
		protocolFeeRewardManager := staker.NewProtocolFeeRewardManager()
		err := store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager)
		if err != nil {
			return err
		}
	}

	// Initialize LaunchpadProjectDeposits
	if !store.HasLaunchpadProjectDepositsStoreKey() {
		launchpadDeposits := staker.NewLaunchpadProjectDeposits()
		err := store.SetLaunchpadProjectDeposits(0, rlm, launchpadDeposits)
		if err != nil {
			return err
		}
	}

	// Initialize DelegationManager
	if !store.HasDelegationManagerStoreKey() {
		delegationManager := staker.NewDelegationManager()
		err := store.SetDelegationManager(0, rlm, delegationManager)
		if err != nil {
			return err
		}
	}

	return nil
}
