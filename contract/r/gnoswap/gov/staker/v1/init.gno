package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
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
		err := store.SetUnDelegationLockupPeriod(int64(7 * 24 * 60 * 60)) // 7 days default
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

	// TODO: consider NewBPTreeN(64) (RULE 4) — Get/Set/Remove, N=1k~10k.
	// Benchmark (N=1000): BPT64 Get -3.4%, Set -3.4%. BPT128 is WORSE.
	if !store.HasDelegationsStoreKey() {
		err := store.SetDelegations(bptree.NewBPTree32())
		if err != nil {
			return err
		}
	}

	// Initialize total delegation history (timestamp -> int64)
	if !store.HasTotalDelegationHistoryStoreKey() {
		err := store.SetTotalDelegationHistory(staker.NewUintTree())
		if err != nil {
			return err
		}
	}

	// TODO: consider NewBPTreeN(64) (RULE 4) — outer N grows with delegator count.
	// Initialize user delegation history (address -> *UintTree[timestamp -> int64])
	if !store.HasUserDelegationHistoryStoreKey() {
		err := store.SetUserDelegationHistory(bptree.NewBPTree32())
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
