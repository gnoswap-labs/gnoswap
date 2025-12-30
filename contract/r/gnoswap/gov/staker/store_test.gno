package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
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
	tests := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "kvStore should be initialized",
			verifyFn: func(t *testing.T) {
				uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
			},
		},
		{
			name: "domain address should not be empty",
			verifyFn: func(t *testing.T) {
				domainAddr := kvStore.GetDomainAddress()
				uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			tt.verifyFn(t)
		})
	}
}

func TestStore_AuthorizedCallers(t *testing.T) {
	tests := []struct {
		name                          string
		callerRealm                   runtime.Realm
		expectedErrorWithRead         bool
		expectedErrorWithWrite        bool
		expectedErrorMessageWithRead  string
		expectedErrorMessageWithWrite string
	}{
		{
			name:        "domain address",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v2"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "governance has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "panic with no permission realm",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                   "user has permission",
			callerRealm:            testing.NewUserRealm(testutils.TestAddress("bob")),
			expectedErrorWithRead:  false,
			expectedErrorWithWrite: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			resetTestState(t)

			gs := NewGovStakerStore(kvStore)
			initRegisterReadableContract()

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			if !gs.HasDelegationsStoreKey() {
				gs.SetDelegations(avl.NewTree())
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					gs.GetAllDelegations()
				})
			} else {
				gs.GetAllDelegations()
			}

			err := gs.SetDelegations(avl.NewTree())
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetUnDelegationLockupPeriod(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get lockup period successfully",
			setupFn: func(gs IGovStakerStore) {
				gs.SetUnDelegationLockupPeriod(86400)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should have lockup period after setting")
				retrieved := gs.GetUnDelegationLockupPeriod()
				uassert.Equal(t, int64(86400), retrieved)
			},
		},
		{
			name: "should not have lockup period initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should not have lockup period initially")
			},
		},
		{
			name: "panic when getting uninitialized lockup period",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetUnDelegationLockupPeriod()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized lockup period",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetEmissionRewardBalance(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get emission reward balance successfully",
			setupFn: func(gs IGovStakerStore) {
				gs.SetEmissionRewardBalance(1000000)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasEmissionRewardBalanceStoreKey(), "should have emission reward balance after setting")
				retrieved := gs.GetEmissionRewardBalance()
				uassert.Equal(t, int64(1000000), retrieved)
			},
		},
		{
			name: "should not have emission reward balance initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasEmissionRewardBalanceStoreKey(), "should not have emission reward balance initially")
			},
		},
		{
			name: "panic when getting uninitialized emission reward balance",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetEmissionRewardBalance()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized emission reward balance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetTotalDelegatedAmount(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total delegated amount successfully",
			setupFn: func(gs IGovStakerStore) {
				gs.SetTotalDelegatedAmount(500000)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalDelegatedAmountStoreKey(), "should have total delegated amount after setting")
				retrieved := gs.GetTotalDelegatedAmount()
				uassert.Equal(t, int64(500000), retrieved)
			},
		},
		{
			name: "should not have total delegated amount initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalDelegatedAmountStoreKey(), "should not have total delegated amount initially")
			},
		},
		{
			name: "panic when getting uninitialized total delegated amount",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetTotalDelegatedAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total delegated amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetTotalLockedAmount(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total locked amount successfully",
			setupFn: func(gs IGovStakerStore) {
				gs.SetTotalLockedAmount(250000)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalLockedAmountStoreKey(), "should have total locked amount after setting")
				retrieved := gs.GetTotalLockedAmount()
				uassert.Equal(t, int64(250000), retrieved)
			},
		},
		{
			name: "should not have total locked amount initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalLockedAmountStoreKey(), "should not have total locked amount initially")
			},
		},
		{
			name: "panic when getting uninitialized total locked amount",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetTotalLockedAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total locked amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetDelegations(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegations successfully",
			setupFn: func(gs IGovStakerStore) {
				delegations := avl.NewTree()
				gs.SetDelegations(delegations)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationsStoreKey(), "should have delegations after setting")
				retrieved := gs.GetAllDelegations()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have delegations initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationsStoreKey(), "should not have delegations initially")
			},
		},
		{
			name: "panic when getting uninitialized delegations",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetAllDelegations()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegations",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetDelegation(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "SetAndGet",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := avl.NewTree()
				err := gs.SetDelegations(delegations)
				uassert.NoError(t, err)

				uassert.False(t, gs.HasDelegation(1), "delegation 1 should not exist")

				delegation := NewDelegation(1, address("g1delegator"), address("g1delegateTo"), 1000, 100, 12345)

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
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := avl.NewTree()
				err := gs.SetDelegations(delegations)
				uassert.NoError(t, err)

				delegation := NewDelegation(1, address("g1delegator"), address("g1delegateTo"), 1000, 100, 12345)

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
			tc.verifyFn(t)
		})
	}
}

func TestStoreSetAndGetDelegationCounter(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegation counter successfully",
			setupFn: func(gs IGovStakerStore) {
				counter := NewCounter()
				for i := 0; i < 10; i++ {
					counter.Next()
				}
				gs.SetDelegationCounter(counter)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationCounterStoreKey(), "should have delegation counter after setting")
				retrieved := gs.GetDelegationCounter()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(10), retrieved.Get())
			},
		},
		{
			name: "should not have delegation counter initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationCounterStoreKey(), "should not have delegation counter initially")
			},
		},
		{
			name: "panic when getting uninitialized delegation counter",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetDelegationCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegation counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetTotalDelegationHistory(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total delegation history successfully",
			setupFn: func(gs IGovStakerStore) {
				history := NewUintTree()
				gs.SetTotalDelegationHistory(history)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalDelegationHistoryStoreKey(), "should have total delegation history after setting")
				retrieved := gs.GetTotalDelegationHistory()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have total delegation history initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalDelegationHistoryStoreKey(), "should not have total delegation history initially")
			},
		},
		{
			name: "panic when getting uninitialized total delegation history",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetTotalDelegationHistory()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total delegation history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetUserDelegationHistory(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get user delegation history successfully",
			setupFn: func(gs IGovStakerStore) {
				history := avl.NewTree()
				gs.SetUserDelegationHistory(history)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasUserDelegationHistoryStoreKey(), "should have user delegation history after setting")
				retrieved := gs.GetUserDelegationHistory()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have user delegation history initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasUserDelegationHistoryStoreKey(), "should not have user delegation history initially")
			},
		},
		{
			name: "panic when getting uninitialized user delegation history",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetUserDelegationHistory()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized user delegation history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetEmissionRewardManager(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get emission reward manager successfully",
			setupFn: func(gs IGovStakerStore) {
				manager := &EmissionRewardManager{}
				gs.SetEmissionRewardManager(manager)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasEmissionRewardManagerStoreKey(), "should have emission reward manager after setting")
				retrieved := gs.GetEmissionRewardManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have emission reward manager initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasEmissionRewardManagerStoreKey(), "should not have emission reward manager initially")
			},
		},
		{
			name: "panic when getting uninitialized emission reward manager",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetEmissionRewardManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized emission reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetProtocolFeeRewardManager(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get protocol fee reward manager successfully",
			setupFn: func(gs IGovStakerStore) {
				manager := &ProtocolFeeRewardManager{}
				gs.SetProtocolFeeRewardManager(manager)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should have protocol fee reward manager after setting")
				retrieved := gs.GetProtocolFeeRewardManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have protocol fee reward manager initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should not have protocol fee reward manager initially")
			},
		},
		{
			name: "panic when getting uninitialized protocol fee reward manager",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetProtocolFeeRewardManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized protocol fee reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetDelegationManager(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegation manager successfully",
			setupFn: func(gs IGovStakerStore) {
				manager := &DelegationManager{}
				gs.SetDelegationManager(manager)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationManagerStoreKey(), "should have delegation manager after setting")
				retrieved := gs.GetDelegationManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have delegation manager initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationManagerStoreKey(), "should not have delegation manager initially")
			},
		},
		{
			name: "panic when getting uninitialized delegation manager",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetDelegationManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegation manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreSetAndGetLaunchpadProjectDeposits(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IGovStakerStore)
		testFn       func(*testing.T, IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get launchpad project deposits successfully",
			setupFn: func(gs IGovStakerStore) {
				deposits := &LaunchpadProjectDeposits{}
				gs.SetLaunchpadProjectDeposits(deposits)
			},
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should have launchpad project deposits after setting")
				retrieved := gs.GetLaunchpadProjectDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have launchpad project deposits initially",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should not have launchpad project deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized launchpad project deposits",
			testFn: func(t *testing.T, gs IGovStakerStore) {
				gs.GetLaunchpadProjectDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized launchpad project deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, gs)
		})
	}
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(IGovStakerStore)
		verifyFn func(*testing.T, IGovStakerStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(gs IGovStakerStore) {
				gs.SetUnDelegationLockupPeriod(86400)
				gs.SetEmissionRewardBalance(1000000)
				gs.SetTotalDelegatedAmount(500000)
				gs.SetTotalLockedAmount(250000)

				delegations := avl.NewTree()
				gs.SetDelegations(delegations)

				counter := NewCounter()
				for i := 0; i < 5; i++ {
					counter.Next()
				}
				gs.SetDelegationCounter(counter)

				totalHistory := NewUintTree()
				gs.SetTotalDelegationHistory(totalHistory)

				userHistory := avl.NewTree()
				gs.SetUserDelegationHistory(userHistory)
			},
			verifyFn: func(t *testing.T, gs IGovStakerStore) {
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
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			tt.setupFn(gs)
			tt.verifyFn(t, gs)
		})
	}
}
