package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

func TestGetVotingWeightSnapshot(t *testing.T) {
	tests := []struct {
		name                 string
		current              int64
		smoothingPeriod      int64
		totalDelegation      int64
		expectedWeight       int64
		expectedSnapshotTime int64
		expectError          bool
	}{
		{
			name:                 "valid snapshot with delegation",
			current:              1000,
			smoothingPeriod:      100,
			totalDelegation:      5000,
			expectedWeight:       5000,
			expectedSnapshotTime: 900,
			expectError:          false,
		},
		{
			name:                 "zero smoothing period uses current time",
			current:              1000,
			smoothingPeriod:      0,
			totalDelegation:      3000,
			expectedWeight:       3000,
			expectedSnapshotTime: 1000,
			expectError:          false,
		},
		{
			name:                 "no delegation returns error",
			current:              1000,
			smoothingPeriod:      100,
			totalDelegation:      0,
			expectedWeight:       0,
			expectedSnapshotTime: 900,
			expectError:          true,
		},
		{
			name:                 "negative delegation returns error",
			current:              1000,
			smoothingPeriod:      100,
			totalDelegation:      -100,
			expectedWeight:       0,
			expectedSnapshotTime: 900,
			expectError:          true,
		},
		{
			name:                 "large smoothing period",
			current:              10000,
			smoothingPeriod:      5000,
			totalDelegation:      1000000,
			expectedWeight:       1000000,
			expectedSnapshotTime: 5000,
			expectError:          false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovernanceStore()
			mockAccessor := newMockGovStakerAccessor()
			mockAccessor.SetTotalDelegation(tt.totalDelegation)

			gv := &governanceV1{
				store:          store,
				stakerAccessor: mockAccessor,
			}

			weight, snapshotTime, err := gv.getVotingWeightSnapshot(tt.current, tt.smoothingPeriod)

			if tt.expectError {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tt.expectedWeight, weight)
			}
			uassert.Equal(t, tt.expectedSnapshotTime, snapshotTime)
		})
	}
}

func TestGetProposalUserVotingInfo(t *testing.T) {
	tests := []struct {
		name             string
		setupVotingInfos func() *mockGovernanceStore
		proposalID       int64
		voterAddr        address
		expectedFound    bool
	}{
		{
			name: "voting info exists for user",
			setupVotingInfos: func() *mockGovernanceStore {
				store := newMockGovernanceStore()
				voterAddr := address("g1voter00000000000000000000000000000001")
				votingInfo := governance.NewVotingInfo(1000)
				votingInfos := avl.NewTree()
				votingInfos.Set(voterAddr.String(), votingInfo)
				store.SetProposalVotingInfos(1, votingInfos)
				return store
			},
			proposalID:    1,
			voterAddr:     address("g1voter00000000000000000000000000000001"),
			expectedFound: true,
		},
		{
			name: "voting info does not exist for user",
			setupVotingInfos: func() *mockGovernanceStore {
				store := newMockGovernanceStore()
				store.SetProposalVotingInfos(1, avl.NewTree())
				return store
			},
			proposalID:    1,
			voterAddr:     address("g1voter00000000000000000000000000000001"),
			expectedFound: false,
		},
		{
			name: "proposal has no voting infos",
			setupVotingInfos: func() *mockGovernanceStore {
				store := newMockGovernanceStore()
				return store
			},
			proposalID:    1,
			voterAddr:     address("g1voter00000000000000000000000000000001"),
			expectedFound: false,
		},
		{
			name: "different user not found",
			setupVotingInfos: func() *mockGovernanceStore {
				store := newMockGovernanceStore()
				otherUser := address("g1other00000000000000000000000000000002")
				votingInfo := governance.NewVotingInfo(1000)
				votingInfos := avl.NewTree()
				votingInfos.Set(otherUser.String(), votingInfo)
				store.SetProposalVotingInfos(1, votingInfos)
				return store
			},
			proposalID:    1,
			voterAddr:     address("g1voter00000000000000000000000000000001"),
			expectedFound: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := tt.setupVotingInfos()
			gv := &governanceV1{
				store:          store,
				stakerAccessor: newMockGovStakerAccessor(),
			}

			votingInfo, found := gv.getProposalUserVotingInfo(tt.proposalID, tt.voterAddr)

			uassert.Equal(t, tt.expectedFound, found)
			if tt.expectedFound {
				uassert.True(t, votingInfo != nil)
			}
		})
	}
}

func TestUpdateProposalUserVotes(t *testing.T) {
	tests := []struct {
		name          string
		proposalID    int64
		numVotes      int
		expectedCount int
	}{
		{
			name:          "update with single vote",
			proposalID:    1,
			numVotes:      1,
			expectedCount: 1,
		},
		{
			name:          "update with multiple votes",
			proposalID:    1,
			numVotes:      3,
			expectedCount: 3,
		},
		{
			name:          "update with empty votes",
			proposalID:    1,
			numVotes:      0,
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovernanceStore()
			gv := &governanceV1{
				store:          store,
				stakerAccessor: newMockGovStakerAccessor(),
			}

			// Create proposal
			proposal := createTestProposal(tt.proposalID)
			store.SetProposal(tt.proposalID, proposal)

			// Create voting infos
			votingInfos := avl.NewTree()
			for i := 0; i < tt.numVotes; i++ {
				voterAddr := address("g1voter0000000000000000000000000000000" + formatInt(int64(i)))
				votingInfo := governance.NewVotingInfo(1000)
				votingInfos.Set(voterAddr.String(), votingInfo)
			}

			// Update votes
			err := gv.updateProposalUserVotes(proposal, votingInfos)

			uassert.NoError(t, err)

			// Verify stored votes
			storedVotes, exists := store.GetProposalVotingInfos(tt.proposalID)
			uassert.True(t, exists)
			uassert.Equal(t, tt.expectedCount, storedVotes.Size())
		})
	}
}

func createTestProposal(id int64) *governance.Proposal {
	config := governance.Config{
		VotingStartDelay:              100,
		VotingPeriod:                  1000,
		VotingWeightSmoothingDuration: 50,
		Quorum:                        30,
		ProposalCreationThreshold:     100,
		ExecutionDelay:                100,
		ExecutionWindow:               500,
	}

	createdAt := int64(1000)

	return governance.NewProposal(
		id,
		NewProposalStatus(config, 10000, true, createdAt),
		governance.NewProposalMetadata("Test", "Test proposal"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1proposer"),
		1,
		createdAt-config.VotingWeightSmoothingDuration,
		createdAt,
		100,
	)
}
