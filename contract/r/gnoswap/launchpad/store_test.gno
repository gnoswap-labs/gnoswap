package launchpad

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v2"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
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

			ls := NewLaunchpadStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
			if !ls.HasProjectsKey() {
				ls.SetProjects(avl.NewTree())
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					ls.GetProjects()
				})
			} else {
				ls.GetProjects()
			}

			err := ls.SetProjects(avl.NewTree())
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetProjects(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(ILaunchpadStore)
		testFn       func(*testing.T, ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get projects successfully",
			setupFn: func(ls ILaunchpadStore) {
				projects := avl.NewTree()
				ls.SetProjects(projects)
			},
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasProjectsKey(), "should have projects after setting")
				retrieved := ls.GetProjects()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have projects initially",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasProjectsKey(), "should not have projects initially")
			},
		},
		{
			name: "panic when getting uninitialized projects",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				ls.GetProjects()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized projects",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ls)
		})
	}
}

func TestStoreSetAndGetProjectTierRewardManagers(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(ILaunchpadStore)
		testFn       func(*testing.T, ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get project tier reward managers successfully",
			setupFn: func(ls ILaunchpadStore) {
				managers := avl.NewTree()
				ls.SetProjectTierRewardManagers(managers)
			},
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasProjectTierRewardManagersKey(), "should have project tier reward managers after setting")
				retrieved := ls.GetProjectTierRewardManagers()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have project tier reward managers initially",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasProjectTierRewardManagersKey(), "should not have project tier reward managers initially")
			},
		},
		{
			name: "panic when getting uninitialized project tier reward managers",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				ls.GetProjectTierRewardManagers()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized project tier reward managers",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ls)
		})
	}
}

func TestStoreSetAndGetDepositCounter(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(ILaunchpadStore)
		testFn       func(*testing.T, ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposit counter successfully",
			setupFn: func(ls ILaunchpadStore) {
				counter := &Counter{}
				ls.SetDepositCounter(counter)
			},
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasDepositCounterStoreKey(), "should have deposit counter after setting")
				retrieved := ls.GetDepositCounter()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposit counter initially",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasDepositCounterStoreKey(), "should not have deposit counter initially")
			},
		},
		{
			name: "panic when getting uninitialized deposit counter",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				ls.GetDepositCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposit counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ls)
		})
	}
}

func TestStoreNextDepositID(t *testing.T) {
	resetTestState(t)

	ls := NewLaunchpadStore(kvStore)

	counter := &Counter{}
	err := ls.SetDepositCounter(counter)
	uassert.NoError(t, err)

	id1 := ls.NextDepositID()
	uassert.Equal(t, "1", id1)

	id2 := ls.NextDepositID()
	uassert.Equal(t, "2", id2)

	id3 := ls.NextDepositID()
	uassert.Equal(t, "3", id3)
}

func TestStoreSetAndGetDeposits(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(ILaunchpadStore)
		testFn       func(*testing.T, ILaunchpadStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposits successfully",
			setupFn: func(ls ILaunchpadStore) {
				deposits := avl.NewTree()
				ls.SetDeposits(deposits)
			},
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.True(t, ls.HasDepositsKey(), "should have deposits after setting")
				retrieved := ls.GetDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposits initially",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				uassert.False(t, ls.HasDepositsKey(), "should not have deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized deposits",
			testFn: func(t *testing.T, ls ILaunchpadStore) {
				ls.GetDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ls := NewLaunchpadStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ls)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ls)
		})
	}
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(ILaunchpadStore)
		verifyFn func(*testing.T, ILaunchpadStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(ls ILaunchpadStore) {
				projects := avl.NewTree()
				projects.Set("project1", "data1")
				ls.SetProjects(projects)

				managers := avl.NewTree()
				managers.Set("manager1", "mdata1")
				ls.SetProjectTierRewardManagers(managers)

				counter := &Counter{}
				ls.SetDepositCounter(counter)

				deposits := avl.NewTree()
				deposits.Set("deposit1", "ddata1")
				ls.SetDeposits(deposits)
			},
			verifyFn: func(t *testing.T, ls ILaunchpadStore) {
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
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ls := NewLaunchpadStore(kvStore)

			tt.setupFn(ls)
			tt.verifyFn(t, ls)
		})
	}
}
