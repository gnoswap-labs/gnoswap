package launchpad

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
			resetTestState(cur, t)
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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v2"),
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
			resetTestState(cur, t)

			ls := NewLaunchpadStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
			if !ls.HasProjectsKey() {
				ls.SetProjects(0, cur, bptree.NewBPTreeN(16))
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, cur, tc.expectedErrorMessageWithRead, func() {
					ls.GetProjects()
				})
			} else {
				ls.GetProjects()
			}

			err := ls.SetProjects(0, cur, bptree.NewBPTreeN(16))
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetProjects(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ls ILaunchpadStore)
		testFn       func(cur realm, t *testing.T, ls ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get projects successfully",
			setupFn: func(cur realm, ls ILaunchpadStore) {
				projects := bptree.NewBPTreeN(16)
				ls.SetProjects(0, cur, projects)
			},
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasProjectsKey(), "should have projects after setting")
				retrieved := ls.GetProjects()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have projects initially",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasProjectsKey(), "should not have projects initially")
			},
		},
		{
			name: "panic when getting uninitialized projects",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				ls.GetProjects()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized projects",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ls)
		})
	}
}

func TestStoreSetAndGetProjectTierRewardManagers(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ls ILaunchpadStore)
		testFn       func(cur realm, t *testing.T, ls ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get project tier reward managers successfully",
			setupFn: func(cur realm, ls ILaunchpadStore) {
				managers := bptree.NewBPTreeN(16)
				ls.SetProjectTierRewardManagers(0, cur, managers)
			},
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasProjectTierRewardManagersKey(), "should have project tier reward managers after setting")
				retrieved := ls.GetProjectTierRewardManagers()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have project tier reward managers initially",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasProjectTierRewardManagersKey(), "should not have project tier reward managers initially")
			},
		},
		{
			name: "panic when getting uninitialized project tier reward managers",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				ls.GetProjectTierRewardManagers()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized project tier reward managers",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ls)
		})
	}
}

func TestStoreSetAndGetDepositCounter(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ls ILaunchpadStore)
		testFn       func(cur realm, t *testing.T, ls ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposit counter successfully",
			setupFn: func(cur realm, ls ILaunchpadStore) {
				counter := &Counter{}
				ls.SetDepositCounter(0, cur, counter)
			},
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasDepositCounterStoreKey(), "should have deposit counter after setting")
				retrieved := ls.GetDepositCounter()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposit counter initially",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasDepositCounterStoreKey(), "should not have deposit counter initially")
			},
		},
		{
			name: "panic when getting uninitialized deposit counter",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				ls.GetDepositCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposit counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ls)
		})
	}
}

func TestStoreNextDepositID(cur realm, t *testing.T) {
	resetTestState(cur, t)

	ls := NewLaunchpadStore(kvStore)

	counter := &Counter{}
	err := ls.SetDepositCounter(0, cur, counter)
	uassert.NoError(t, err)

	id1 := ls.NextDepositID()
	uassert.Equal(t, "1", id1)

	id2 := ls.NextDepositID()
	uassert.Equal(t, "2", id2)

	id3 := ls.NextDepositID()
	uassert.Equal(t, "3", id3)
}

func TestStoreSetAndGetDeposits(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ls ILaunchpadStore)
		testFn       func(cur realm, t *testing.T, ls ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposits successfully",
			setupFn: func(cur realm, ls ILaunchpadStore) {
				deposits := bptree.NewBPTreeN(16)
				ls.SetDeposits(0, cur, deposits)
			},
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasDepositsKey(), "should have deposits after setting")
				retrieved := ls.GetDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposits initially",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasDepositsKey(), "should not have deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized deposits",
			testFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				ls.GetDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ls)
		})
	}
}

func TestStoreMultipleSetAndGet(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(cur realm, ls ILaunchpadStore)
		verifyFn func(cur realm, t *testing.T, ls ILaunchpadStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(cur realm, ls ILaunchpadStore) {
				projects := bptree.NewBPTreeN(16)
				projects.Set("project1", "data1")
				ls.SetProjects(0, cur, projects)

				managers := bptree.NewBPTreeN(16)
				managers.Set("manager1", "mdata1")
				ls.SetProjectTierRewardManagers(0, cur, managers)

				counter := &Counter{}
				ls.SetDepositCounter(0, cur, counter)

				deposits := bptree.NewBPTreeN(16)
				deposits.Set("deposit1", "ddata1")
				ls.SetDeposits(0, cur, deposits)
			},
			verifyFn: func(cur realm, t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasProjectsKey())
				uassert.True(t, ls.HasProjectTierRewardManagersKey())
				uassert.True(t, ls.HasDepositCounterStoreKey())
				uassert.True(t, ls.HasDepositsKey())

				retrievedProjects := ls.GetProjects()
				val, _ := retrievedProjects.Get("project1")
				uassert.Equal(t, "data1", val)

				retrievedManagers := ls.GetProjectTierRewardManagers()
				val, _ = retrievedManagers.Get("manager1")
				uassert.Equal(t, "mdata1", val)

				retrievedCounter := ls.GetDepositCounter()
				uassert.NotEqual(t, nil, retrievedCounter)

				retrievedDeposits := ls.GetDeposits()
				val, _ = retrievedDeposits.Get("deposit1")
				uassert.Equal(t, "ddata1", val)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			ls := NewLaunchpadStore(kvStore)

			tt.setupFn(cur, ls)
			tt.verifyFn(cur, t, ls)
		})
	}
}
