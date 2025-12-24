package staker

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

// TestStore_int64ToString tests the private int64ToString function
func TestStore_int64ToString(t *testing.T) {
	tests := []struct {
		name           string
		input          int64
		expectedOutput string
	}{
		{
			name:           "zero",
			input:          0,
			expectedOutput: "0",
		},
		{
			name:           "positive small number",
			input:          123,
			expectedOutput: "123",
		},
		{
			name:           "negative small number",
			input:          -456,
			expectedOutput: "-456",
		},
		{
			name:           "max int64",
			input:          9223372036854775807,
			expectedOutput: "9223372036854775807",
		},
		{
			name:           "min int64",
			input:          -9223372036854775808,
			expectedOutput: "-9223372036854775808",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := int64ToString(tc.input)

			// then
			uassert.Equal(t, result, tc.expectedOutput)
		})
	}
}

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStoreSetAndGetUnDelegationLockupPeriod(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should not have lockup period initially")

		err := gs.SetUnDelegationLockupPeriod(86400)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should have lockup period after setting")

		retrieved := gs.GetUnDelegationLockupPeriod()
		uassert.Equal(t, int64(86400), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized lockup period")
		}()

		gs.GetUnDelegationLockupPeriod()
	})
}

func TestStoreSetAndGetEmissionRewardBalance(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasEmissionRewardBalanceStoreKey(), "should not have emission reward balance initially")

		err := gs.SetEmissionRewardBalance(1000000)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasEmissionRewardBalanceStoreKey(), "should have emission reward balance after setting")

		retrieved := gs.GetEmissionRewardBalance()
		uassert.Equal(t, int64(1000000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized emission reward balance")
		}()

		gs.GetEmissionRewardBalance()
	})
}

func TestStoreSetAndGetTotalDelegatedAmount(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasTotalDelegatedAmountStoreKey(), "should not have total delegated amount initially")

		err := gs.SetTotalDelegatedAmount(500000)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasTotalDelegatedAmountStoreKey(), "should have total delegated amount after setting")

		retrieved := gs.GetTotalDelegatedAmount()
		uassert.Equal(t, int64(500000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized total delegated amount")
		}()

		gs.GetTotalDelegatedAmount()
	})
}

func TestStoreSetAndGetTotalLockedAmount(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasTotalLockedAmountStoreKey(), "should not have total locked amount initially")

		err := gs.SetTotalLockedAmount(250000)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasTotalLockedAmountStoreKey(), "should have total locked amount after setting")

		retrieved := gs.GetTotalLockedAmount()
		uassert.Equal(t, int64(250000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized total locked amount")
		}()

		gs.GetTotalLockedAmount()
	})
}

func TestStoreSetAndGetDelegations(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasDelegationsStoreKey(), "should not have delegations initially")

		delegations := avl.NewTree()
		err := gs.SetDelegations(delegations)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasDelegationsStoreKey(), "should have delegations after setting")

		retrieved := gs.GetAllDelegations()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized delegations")
		}()

		gs.GetAllDelegations()
	})
}

func TestStoreSetAndGetDelegation(t *testing.T) {
	testCases := []struct {
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "SetAndGet",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := avl.NewTree()
				err := gs.SetDelegations(delegations)
				uassert.NoError(t, err)

				uassert.False(t, gs.HasDelegation(1), "delegation 1 should not exist")

				delegation := NewDelegation(1, "g1delegator", "g1delegateTo", 1000, 100, 12345)

				err = gs.SetDelegation(1, delegation)
				uassert.NoError(t, err)

				uassert.True(t, gs.HasDelegation(1), "delegation 1 should exist after setting")

				retrieved, exists := gs.GetDelegation(1)
				uassert.True(t, exists, "delegation 1 should exist")
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, address("g1delegator"), retrieved.DelegateFrom())
				uassert.Equal(t, int64(1000), retrieved.TotalDelegatedAmount())
			},
		},
		{
			name: "Remove",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := avl.NewTree()
				err := gs.SetDelegations(delegations)
				uassert.NoError(t, err)

				delegation := NewDelegation(1, "g1delegator", "g1delegateTo", 1000, 100, 12345)

				err = gs.SetDelegation(1, delegation)
				uassert.NoError(t, err)
				uassert.True(t, gs.HasDelegation(1), "delegation 1 should exist")

				err = gs.RemoveDelegation(1)
				uassert.NoError(t, err)
				uassert.False(t, gs.HasDelegation(1), "delegation 1 should be removed")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
		})
	}
}

func TestStoreSetAndGetDelegationCounter(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasDelegationCounterStoreKey(), "should not have delegation counter initially")

		counter := NewCounter()
		for i := 0; i < 10; i++ {
			counter.Next()
		}
		err := gs.SetDelegationCounter(counter)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasDelegationCounterStoreKey(), "should have delegation counter after setting")

		retrieved := gs.GetDelegationCounter()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, int64(10), retrieved.Get())
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized delegation counter")
		}()

		gs.GetDelegationCounter()
	})
}

func TestStoreSetAndGetTotalDelegationHistory(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasTotalDelegationHistoryStoreKey(), "should not have total delegation history initially")

		history := NewUintTree()
		err := gs.SetTotalDelegationHistory(history)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasTotalDelegationHistoryStoreKey(), "should have total delegation history after setting")

		retrieved := gs.GetTotalDelegationHistory()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized total delegation history")
		}()

		gs.GetTotalDelegationHistory()
	})
}

func TestStoreSetAndGetUserDelegationHistory(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasUserDelegationHistoryStoreKey(), "should not have user delegation history initially")

		history := avl.NewTree()
		err := gs.SetUserDelegationHistory(history)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasUserDelegationHistoryStoreKey(), "should have user delegation history after setting")

		retrieved := gs.GetUserDelegationHistory()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized user delegation history")
		}()

		gs.GetUserDelegationHistory()
	})
}

func TestStoreSetAndGetEmissionRewardManager(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasEmissionRewardManagerStoreKey(), "should not have emission reward manager initially")

		manager := &EmissionRewardManager{}
		err := gs.SetEmissionRewardManager(manager)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasEmissionRewardManagerStoreKey(), "should have emission reward manager after setting")

		retrieved := gs.GetEmissionRewardManager()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized emission reward manager")
		}()

		gs.GetEmissionRewardManager()
	})
}

func TestStoreSetAndGetProtocolFeeRewardManager(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should not have protocol fee reward manager initially")

		manager := &ProtocolFeeRewardManager{}
		err := gs.SetProtocolFeeRewardManager(manager)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should have protocol fee reward manager after setting")

		retrieved := gs.GetProtocolFeeRewardManager()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized protocol fee reward manager")
		}()

		gs.GetProtocolFeeRewardManager()
	})
}

func TestStoreSetAndGetDelegationManager(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasDelegationManagerStoreKey(), "should not have delegation manager initially")

		manager := &DelegationManager{}
		err := gs.SetDelegationManager(manager)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasDelegationManagerStoreKey(), "should have delegation manager after setting")

		retrieved := gs.GetDelegationManager()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized delegation manager")
		}()

		gs.GetDelegationManager()
	})
}

func TestStoreSetAndGetLaunchpadProjectDeposits(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		uassert.False(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should not have launchpad project deposits initially")

		deposits := &LaunchpadProjectDeposits{}
		err := gs.SetLaunchpadProjectDeposits(deposits)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should have launchpad project deposits after setting")

		retrieved := gs.GetLaunchpadProjectDeposits()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized launchpad project deposits")
		}()

		gs.GetLaunchpadProjectDeposits()
	})
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	resetTestState(t)

	gs := NewGovStakerStore(kvStore)

	err := gs.SetUnDelegationLockupPeriod(86400)
	uassert.NoError(t, err)

	err = gs.SetEmissionRewardBalance(1000000)
	uassert.NoError(t, err)

	err = gs.SetTotalDelegatedAmount(500000)
	uassert.NoError(t, err)

	err = gs.SetTotalLockedAmount(250000)
	uassert.NoError(t, err)

	delegations := avl.NewTree()
	err = gs.SetDelegations(delegations)
	uassert.NoError(t, err)

	counter := NewCounter()
	for i := 0; i < 5; i++ {
		counter.Next()
	}
	err = gs.SetDelegationCounter(counter)
	uassert.NoError(t, err)

	totalHistory := NewUintTree()
	err = gs.SetTotalDelegationHistory(totalHistory)
	uassert.NoError(t, err)

	userHistory := avl.NewTree()
	err = gs.SetUserDelegationHistory(userHistory)
	uassert.NoError(t, err)

	uassert.True(t, gs.HasUnDelegationLockupPeriodStoreKey())
	uassert.True(t, gs.HasEmissionRewardBalanceStoreKey())
	uassert.True(t, gs.HasTotalDelegatedAmountStoreKey())
	uassert.True(t, gs.HasTotalLockedAmountStoreKey())
	uassert.True(t, gs.HasDelegationsStoreKey())
	uassert.True(t, gs.HasDelegationCounterStoreKey())
	uassert.True(t, gs.HasTotalDelegationHistoryStoreKey())
	uassert.True(t, gs.HasUserDelegationHistoryStoreKey())

	uassert.Equal(t, int64(86400), gs.GetUnDelegationLockupPeriod())
	uassert.Equal(t, int64(1000000), gs.GetEmissionRewardBalance())
	uassert.Equal(t, int64(500000), gs.GetTotalDelegatedAmount())
	uassert.Equal(t, int64(250000), gs.GetTotalLockedAmount())
	uassert.Equal(t, int64(5), gs.GetDelegationCounter().Get())
	uassert.NotEqual(t, nil, gs.GetAllDelegations())
	uassert.NotEqual(t, nil, gs.GetTotalDelegationHistory())
	uassert.NotEqual(t, nil, gs.GetUserDelegationHistory())
}

