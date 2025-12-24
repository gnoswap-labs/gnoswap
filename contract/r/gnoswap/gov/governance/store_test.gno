package governance

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v2"),
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

			gs := NewGovernanceStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))
			if !gs.HasConfigsStoreKey() {
				gs.SetConfigs(avl.NewTree())
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					gs.GetConfigs()
				})
			} else {
				gs.GetConfigs()
			}

			err := gs.SetConfigs(avl.NewTree())
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetConfigCounter(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		uassert.False(t, gs.HasConfigCounterStoreKey(), "should not have config counter initially")

		counter := NewCounter()
		counter.Set(5)
		err := gs.SetConfigCounter(counter)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasConfigCounterStoreKey(), "should have config counter after setting")

		retrieved := gs.GetConfigCounter()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, int64(5), retrieved.Get())
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized config counter")
		}()

		gs.GetConfigCounter()
	})
}

func TestStoreSetAndGetProposalCounter(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		uassert.False(t, gs.HasProposalCounterStoreKey(), "should not have proposal counter initially")

		counter := NewCounter()
		counter.Set(10)
		err := gs.SetProposalCounter(counter)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasProposalCounterStoreKey(), "should have proposal counter after setting")

		retrieved := gs.GetProposalCounter()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, int64(10), retrieved.Get())
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized proposal counter")
		}()

		gs.GetProposalCounter()
	})
}

func TestStoreSetAndGetConfigs(t *testing.T) {
	resetTestState(t)

	gs := NewGovernanceStore(kvStore)

	uassert.False(t, gs.HasConfigsStoreKey(), "should not have configs initially")

	configs := avl.NewTree()
	err := gs.SetConfigs(configs)
	uassert.NoError(t, err)

	uassert.True(t, gs.HasConfigsStoreKey(), "should have configs after setting")
}

func TestStoreSetAndGetConfig(t *testing.T) {
	testCases := []struct {
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "SetAndGet",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				configs := avl.NewTree()
				err := gs.SetConfigs(configs)
				uassert.NoError(t, err)

				_, exists := gs.GetConfig(1)
				uassert.False(t, exists, "config version 1 should not exist")

				config := Config{
					VotingStartDelay:              100,
					VotingPeriod:                  200,
					VotingWeightSmoothingDuration: 300,
					Quorum:                        50,
					ProposalCreationThreshold:     1000,
					ExecutionDelay:                400,
					ExecutionWindow:               500,
				}

				err = gs.SetConfig(1, config)
				uassert.NoError(t, err)

				retrieved, exists := gs.GetConfig(1)
				uassert.True(t, exists, "config version 1 should exist")
				uassert.Equal(t, int64(100), retrieved.VotingStartDelay)
				uassert.Equal(t, int64(200), retrieved.VotingPeriod)
				uassert.Equal(t, int64(50), retrieved.Quorum)
			},
		},
		{
			name: "NotInitialized",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				configs := avl.NewTree()
				err := gs.SetConfigs(configs)
				uassert.NoError(t, err)

				_, exists := gs.GetConfig(1)
				uassert.False(t, exists, "config should not exist when not set")
			},
		},
		{
			name: "NotInitializedError",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				config := Config{
					VotingStartDelay: 100,
					VotingPeriod:     200,
				}

				err := gs.SetConfig(1, config)
				uassert.ErrorContains(t, err, "configs store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
		})
	}
}

func TestStoreSetAndGetProposals(t *testing.T) {
	resetTestState(t)

	gs := NewGovernanceStore(kvStore)

	uassert.False(t, gs.HasProposalsStoreKey(), "should not have proposals initially")

	proposals := avl.NewTree()
	err := gs.SetProposals(proposals)
	uassert.NoError(t, err)

	uassert.True(t, gs.HasProposalsStoreKey(), "should have proposals after setting")
}

func TestStoreSetAndGetProposal(t *testing.T) {
	testCases := []struct {
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "SetAndGet",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				proposals := avl.NewTree()
				err := gs.SetProposals(proposals)
				uassert.NoError(t, err)

				_, exists := gs.GetProposal(1)
				uassert.False(t, exists, "proposal 1 should not exist")

				proposal := &Proposal{
					id:       1,
					proposer: "g1test",
				}

				err = gs.SetProposal(1, proposal)
				uassert.NoError(t, err)

				retrieved, exists := gs.GetProposal(1)
				uassert.True(t, exists, "proposal 1 should exist")
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(1), retrieved.id)
				uassert.Equal(t, address("g1test"), retrieved.proposer)
			},
		},
		{
			name: "NotInitializedError",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				proposal := &Proposal{
					id: 1,
				}

				err := gs.SetProposal(1, proposal)
				uassert.ErrorContains(t, err, "proposals store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
		})
	}
}

func TestStoreSetAndGetProposalUserVotingInfos(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		uassert.False(t, gs.HasProposalUserVotingInfosStoreKey(), "should not have proposal user voting infos initially")

		votingInfos := avl.NewTree()
		err := gs.SetProposalUserVotingInfos(votingInfos)
		uassert.NoError(t, err)

		uassert.True(t, gs.HasProposalUserVotingInfosStoreKey(), "should have proposal user voting infos after setting")

		retrieved := gs.GetProposalUserVotingInfos()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		gs := NewGovernanceStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized proposal user voting infos")
		}()

		gs.GetProposalUserVotingInfos()
	})
}

func TestStoreSetAndGetProposalVotingInfos(t *testing.T) {
	testCases := []struct {
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "SetAndGet",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				votingInfos := avl.NewTree()
				err := gs.SetProposalUserVotingInfos(votingInfos)
				uassert.NoError(t, err)

				_, exists := gs.GetProposalVotingInfos(1)
				uassert.False(t, exists, "proposal voting infos for proposal 1 should not exist")

				proposalVotingInfo := avl.NewTree()
				proposalVotingInfo.Set("user1", "vote_data")

				err = gs.SetProposalVotingInfos(1, proposalVotingInfo)
				uassert.NoError(t, err)

				retrieved, exists := gs.GetProposalVotingInfos(1)
				uassert.True(t, exists, "proposal voting infos for proposal 1 should exist")
				uassert.NotEqual(t, nil, retrieved)

				val, ok := retrieved.Get("user1")
				uassert.True(t, ok, "user1 voting info should exist")
				uassert.Equal(t, "vote_data", val)
			},
		},
		{
			name: "NotInitializedError",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				votingInfo := avl.NewTree()
				err := gs.SetProposalVotingInfos(1, votingInfo)
				uassert.ErrorContains(t, err, "proposal user voting infos store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
		})
	}
}

func TestStoreSetAndGetUserProposals(t *testing.T) {
	resetTestState(t)

	gs := NewGovernanceStore(kvStore)

	uassert.False(t, gs.HasUserProposalsStoreKey(), "should not have user proposals initially")

	userProposals := avl.NewTree()
	err := gs.SetUserProposals(userProposals)
	uassert.NoError(t, err)

	uassert.True(t, gs.HasUserProposalsStoreKey(), "should have user proposals after setting")
}

func TestStoreGetUserProposalIDs(t *testing.T) {
	resetTestState(t)

	gs := NewGovernanceStore(kvStore)

	userProposals := avl.NewTree()
	err := gs.SetUserProposals(userProposals)
	uassert.NoError(t, err)

	_, exists := gs.GetUserProposalIDs("user1")
	uassert.False(t, exists, "user1 proposals should not exist")

	proposalIDs := []int64{1, 2, 3}
	userProposals.Set("user1", proposalIDs)
	err = gs.SetUserProposals(userProposals)
	uassert.NoError(t, err)

	retrieved, exists := gs.GetUserProposalIDs("user1")
	uassert.True(t, exists, "user1 proposals should exist")
	uassert.Equal(t, 3, len(retrieved))
	uassert.Equal(t, int64(1), retrieved[0])
	uassert.Equal(t, int64(2), retrieved[1])
	uassert.Equal(t, int64(3), retrieved[2])
}

func TestStoreAddUserProposal(t *testing.T) {
	testCases := []struct {
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "AddMultiple",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				userProposals := avl.NewTree()
				err := gs.SetUserProposals(userProposals)
				uassert.NoError(t, err)

				err = gs.AddUserProposal("user1", 1)
				uassert.NoError(t, err)

				retrieved, exists := gs.GetUserProposalIDs("user1")
				uassert.True(t, exists, "user1 should have proposals")
				uassert.Equal(t, 1, len(retrieved))
				uassert.Equal(t, int64(1), retrieved[0])

				err = gs.AddUserProposal("user1", 2)
				uassert.NoError(t, err)

				retrieved, exists = gs.GetUserProposalIDs("user1")
				uassert.True(t, exists, "user1 should have proposals")
				uassert.Equal(t, 2, len(retrieved))
				uassert.Equal(t, int64(1), retrieved[0])
				uassert.Equal(t, int64(2), retrieved[1])
			},
		},
		{
			name: "NotInitializedError",
			testFn: func(t *testing.T) {
				resetTestState(t)
				gs := NewGovernanceStore(kvStore)

				err := gs.AddUserProposal("user1", 1)
				uassert.ErrorContains(t, err, "user proposals store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
		})
	}
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	resetTestState(t)

	gs := NewGovernanceStore(kvStore)

	configCounter := NewCounter()
	configCounter.Set(1)
	err := gs.SetConfigCounter(configCounter)
	uassert.NoError(t, err)

	proposalCounter := NewCounter()
	proposalCounter.Set(5)
	err = gs.SetProposalCounter(proposalCounter)
	uassert.NoError(t, err)

	configs := avl.NewTree()
	err = gs.SetConfigs(configs)
	uassert.NoError(t, err)

	proposals := avl.NewTree()
	err = gs.SetProposals(proposals)
	uassert.NoError(t, err)

	votingInfos := avl.NewTree()
	err = gs.SetProposalUserVotingInfos(votingInfos)
	uassert.NoError(t, err)

	userProposals := avl.NewTree()
	err = gs.SetUserProposals(userProposals)
	uassert.NoError(t, err)

	uassert.True(t, gs.HasConfigCounterStoreKey())
	uassert.True(t, gs.HasProposalCounterStoreKey())
	uassert.True(t, gs.HasConfigsStoreKey())
	uassert.True(t, gs.HasProposalsStoreKey())
	uassert.True(t, gs.HasProposalUserVotingInfosStoreKey())
	uassert.True(t, gs.HasUserProposalsStoreKey())

	uassert.Equal(t, int64(1), gs.GetConfigCounter().Get())
	uassert.Equal(t, int64(5), gs.GetProposalCounter().Get())
	uassert.NotEqual(t, nil, gs.GetProposalUserVotingInfos())
}
