package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestInit_initStoreData tests the private initStoreData function
func TestInit_initStoreData(t *testing.T) {
	t.Run("initialize empty store", func(t *testing.T) {
		// given
		store := newMockGovStakerStore()

		// when
		err := initStoreData(store)

		// then
		uassert.Nil(t, err)

		// verify all keys are set
		hasUnDelegationLockup := store.HasUnDelegationLockupPeriodStoreKey()
		hasEmissionRewardBalance := store.HasEmissionRewardBalanceStoreKey()
		hasTotalDelegated := store.HasTotalDelegatedAmountStoreKey()
		hasTotalLocked := store.HasTotalLockedAmountStoreKey()
		hasDelegationCounter := store.HasDelegationCounterStoreKey()
		hasDelegations := store.HasDelegationsStoreKey()
		hasTotalDelegationHistory := store.HasTotalDelegationHistoryStoreKey()
		hasUserDelegationHistory := store.HasUserDelegationHistoryStoreKey()
		hasEmissionRewardManager := store.HasEmissionRewardManagerStoreKey()
		hasProtocolFeeRewardManager := store.HasProtocolFeeRewardManagerStoreKey()
		hasLaunchpadProjectDeposits := store.HasLaunchpadProjectDepositsStoreKey()
		hasDelegationManager := store.HasDelegationManagerStoreKey()

		uassert.True(t, hasUnDelegationLockup)
		uassert.True(t, hasEmissionRewardBalance)
		uassert.True(t, hasTotalDelegated)
		uassert.True(t, hasTotalLocked)
		uassert.True(t, hasDelegationCounter)
		uassert.True(t, hasDelegations)
		uassert.True(t, hasTotalDelegationHistory)
		uassert.True(t, hasUserDelegationHistory)
		uassert.True(t, hasEmissionRewardManager)
		uassert.True(t, hasProtocolFeeRewardManager)
		uassert.True(t, hasLaunchpadProjectDeposits)
		uassert.True(t, hasDelegationManager)
	})

	t.Run("idempotent - does not overwrite existing data", func(t *testing.T) {
		// given
		store := newMockGovStakerStore()

		// First initialization
		err := initStoreData(store)
		uassert.Nil(t, err)

		// Set a custom value
		customPeriod := int64(172800) // 2 days
		err = store.SetUnDelegationLockupPeriod(customPeriod)
		uassert.Nil(t, err)

		// when - initialize again
		err = initStoreData(store)
		uassert.Nil(t, err)

		// then - custom value should be preserved
		period := store.GetUnDelegationLockupPeriod()
		uassert.Equal(t, period, customPeriod) // Should still be 2 days, not reset to default 1 day
	})
}
