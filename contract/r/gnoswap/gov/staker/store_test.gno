package staker

import (
	"chain/runtime"
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestStoreInitialization(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "kvStore should be initialized",
			verifyFn: func(cur realm, t *testing.T) {
				uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
			},
		},
		{
			name: "domain address should not be empty",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := kvStore.GetDomainAddress()
				uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			tt.verifyFn(cur, t)
		})
	}
}

func TestStore_AuthorizedCallers(cur realm, t *testing.T) {
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
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
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
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			gs := NewGovStakerStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			if !gs.HasDelegationsStoreKey() {
				gs.SetDelegations(0, cur, bptree.NewBPTreeN(16))
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, cur, tc.expectedErrorMessageWithRead, func() {
					gs.GetAllDelegations()
				})
			} else {
				gs.GetAllDelegations()
			}

			err := gs.SetDelegations(0, cur, bptree.NewBPTreeN(16))
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetUnDelegationLockupPeriod(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get lockup period successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				gs.SetUnDelegationLockupPeriod(0, cur, 86400)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should have lockup period after setting")
				retrieved := gs.GetUnDelegationLockupPeriod()
				uassert.Equal(t, int64(86400), retrieved)
			},
		},
		{
			name: "should not have lockup period initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasUnDelegationLockupPeriodStoreKey(), "should not have lockup period initially")
			},
		},
		{
			name: "panic when getting uninitialized lockup period",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetUnDelegationLockupPeriod()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized lockup period",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetTotalDelegatedAmount(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total delegated amount successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				gs.SetTotalDelegatedAmount(0, cur, 500000)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalDelegatedAmountStoreKey(), "should have total delegated amount after setting")
				retrieved := gs.GetTotalDelegatedAmount()
				uassert.Equal(t, int64(500000), retrieved)
			},
		},
		{
			name: "should not have total delegated amount initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalDelegatedAmountStoreKey(), "should not have total delegated amount initially")
			},
		},
		{
			name: "panic when getting uninitialized total delegated amount",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetTotalDelegatedAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total delegated amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetTotalLockedAmount(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total locked amount successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				gs.SetTotalLockedAmount(0, cur, 250000)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalLockedAmountStoreKey(), "should have total locked amount after setting")
				retrieved := gs.GetTotalLockedAmount()
				uassert.Equal(t, int64(250000), retrieved)
			},
		},
		{
			name: "should not have total locked amount initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalLockedAmountStoreKey(), "should not have total locked amount initially")
			},
		},
		{
			name: "panic when getting uninitialized total locked amount",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetTotalLockedAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total locked amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetDelegations(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegations successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				delegations := bptree.NewBPTreeN(16)
				gs.SetDelegations(0, cur, delegations)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationsStoreKey(), "should have delegations after setting")
				retrieved := gs.GetAllDelegations()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have delegations initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationsStoreKey(), "should not have delegations initially")
			},
		},
		{
			name: "panic when getting uninitialized delegations",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetAllDelegations()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegations",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetDelegation(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "SetAndGet",
			verifyFn: func(cur realm, t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := bptree.NewBPTreeN(16)
				err := gs.SetDelegations(0, cur, delegations)
				uassert.NoError(t, err)

				uassert.False(t, gs.HasDelegation(1), "delegation 1 should not exist")

				delegation := NewDelegation(1, address("g1delegator"), address("g1delegateTo"), 1000, 100, 12345)

				err = gs.SetDelegation(0, cur, 1, delegation)
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
			verifyFn: func(cur realm, t *testing.T) {
				resetTestState(t)
				gs := NewGovStakerStore(kvStore)

				delegations := bptree.NewBPTreeN(16)
				err := gs.SetDelegations(0, cur, delegations)
				uassert.NoError(t, err)

				delegation := NewDelegation(1, address("g1delegator"), address("g1delegateTo"), 1000, 100, 12345)

				err = gs.SetDelegation(0, cur, 1, delegation)
				uassert.NoError(t, err)
				uassert.True(t, gs.HasDelegation(1), "delegation 1 should exist")

				err = gs.RemoveDelegation(0, cur, 1)
				uassert.NoError(t, err)
				uassert.False(t, gs.HasDelegation(1), "delegation 1 should be removed")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestStoreSetAndGetDelegationCounter(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegation counter successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				counter := NewCounter()
				for i := 0; i < 10; i++ {
					counter.Next()
				}
				gs.SetDelegationCounter(0, cur, counter)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationCounterStoreKey(), "should have delegation counter after setting")
				retrieved := gs.GetDelegationCounter()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(10), retrieved.Get())
			},
		},
		{
			name: "should not have delegation counter initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationCounterStoreKey(), "should not have delegation counter initially")
			},
		},
		{
			name: "panic when getting uninitialized delegation counter",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetDelegationCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegation counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetTotalDelegationHistory(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total delegation history successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				history := NewUintTree()
				gs.SetTotalDelegationHistory(0, cur, history)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasTotalDelegationHistoryStoreKey(), "should have total delegation history after setting")
				retrieved := gs.GetTotalDelegationHistory()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have total delegation history initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasTotalDelegationHistoryStoreKey(), "should not have total delegation history initially")
			},
		},
		{
			name: "panic when getting uninitialized total delegation history",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetTotalDelegationHistory()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total delegation history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetUserDelegationHistory(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get user delegation history successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				history := bptree.NewBPTreeN(16)
				gs.SetUserDelegationHistory(0, cur, history)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasUserDelegationHistoryStoreKey(), "should have user delegation history after setting")
				retrieved := gs.GetUserDelegationHistory()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have user delegation history initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasUserDelegationHistoryStoreKey(), "should not have user delegation history initially")
			},
		},
		{
			name: "panic when getting uninitialized user delegation history",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetUserDelegationHistory()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized user delegation history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetEmissionRewardManager(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get emission reward manager successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				manager := &EmissionRewardManager{}
				gs.SetEmissionRewardManager(0, cur, manager)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasEmissionRewardManagerStoreKey(), "should have emission reward manager after setting")
				retrieved := gs.GetEmissionRewardManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have emission reward manager initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasEmissionRewardManagerStoreKey(), "should not have emission reward manager initially")
			},
		},
		{
			name: "panic when getting uninitialized emission reward manager",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetEmissionRewardManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized emission reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetProtocolFeeRewardManager(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get protocol fee reward manager successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				manager := &ProtocolFeeRewardManager{}
				gs.SetProtocolFeeRewardManager(0, cur, manager)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should have protocol fee reward manager after setting")
				retrieved := gs.GetProtocolFeeRewardManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have protocol fee reward manager initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasProtocolFeeRewardManagerStoreKey(), "should not have protocol fee reward manager initially")
			},
		},
		{
			name: "panic when getting uninitialized protocol fee reward manager",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetProtocolFeeRewardManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized protocol fee reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetDelegationManager(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get delegation manager successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				manager := &DelegationManager{}
				gs.SetDelegationManager(0, cur, manager)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasDelegationManagerStoreKey(), "should have delegation manager after setting")
				retrieved := gs.GetDelegationManager()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have delegation manager initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasDelegationManagerStoreKey(), "should not have delegation manager initially")
			},
		},
		{
			name: "panic when getting uninitialized delegation manager",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetDelegationManager()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized delegation manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreSetAndGetLaunchpadProjectDeposits(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, gs IGovStakerStore)
		testFn       func(cur realm, t *testing.T, gs IGovStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get launchpad project deposits successfully",
			setupFn: func(cur realm, gs IGovStakerStore) {
				deposits := &LaunchpadProjectDeposits{}
				gs.SetLaunchpadProjectDeposits(0, cur, deposits)
			},
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should have launchpad project deposits after setting")
				retrieved := gs.GetLaunchpadProjectDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have launchpad project deposits initially",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.False(t, gs.HasLaunchpadProjectDepositsStoreKey(), "should not have launchpad project deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized launchpad project deposits",
			testFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				gs.GetLaunchpadProjectDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized launchpad project deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, gs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, gs)
		})
	}
}

func TestStoreMultipleSetAndGet(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(cur realm, gs IGovStakerStore)
		verifyFn func(cur realm, t *testing.T, gs IGovStakerStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(cur realm, gs IGovStakerStore) {
				gs.SetUnDelegationLockupPeriod(0, cur, 86400)
				gs.SetTotalDelegatedAmount(0, cur, 500000)
				gs.SetTotalLockedAmount(0, cur, 250000)

				delegations := bptree.NewBPTreeN(16)
				gs.SetDelegations(0, cur, delegations)

				counter := NewCounter()
				for i := 0; i < 5; i++ {
					counter.Next()
				}
				gs.SetDelegationCounter(0, cur, counter)

				totalHistory := NewUintTree()
				gs.SetTotalDelegationHistory(0, cur, totalHistory)

				userHistory := bptree.NewBPTreeN(16)
				gs.SetUserDelegationHistory(0, cur, userHistory)
			},
			verifyFn: func(cur realm, t *testing.T, gs IGovStakerStore) {
				uassert.True(t, gs.HasUnDelegationLockupPeriodStoreKey())
				uassert.True(t, gs.HasTotalDelegatedAmountStoreKey())
				uassert.True(t, gs.HasTotalLockedAmountStoreKey())
				uassert.True(t, gs.HasDelegationsStoreKey())
				uassert.True(t, gs.HasDelegationCounterStoreKey())
				uassert.True(t, gs.HasTotalDelegationHistoryStoreKey())
				uassert.True(t, gs.HasUserDelegationHistoryStoreKey())

				uassert.Equal(t, int64(86400), gs.GetUnDelegationLockupPeriod())
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			gs := NewGovStakerStore(kvStore)

			tt.setupFn(cur, gs)
			tt.verifyFn(cur, t, gs)
		})
	}
}
