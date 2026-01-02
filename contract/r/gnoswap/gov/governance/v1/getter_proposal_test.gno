package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestGetterProposal_All tests all getter functions related to Proposal using table-driven tests.
func TestGetterProposal_All(t *testing.T) {
	tests := []struct {
		name          string
		proposalId    int64
		proposal      *governance.Proposal
		getterFunc    func(gv *governanceV1, id int64) any
		expectedValue any
		expectedPanic bool
		panicMessage  string
	}{
		{
			name:       "Get proposer address",
			proposalId: 1,
			proposal: newTestProposal(
				1,
				NewProposalStatus(governance.Config{
					VotingStartDelay: 100,
					VotingPeriod:     200,
					ExecutionDelay:   100,
					ExecutionWindow:  200,
					Quorum:           50,
				}, 1000, true, time.Now().Unix()),
				governance.NewProposalMetadata("TestTitle", "TestDesc"),
				governance.NewProposalData(governance.Text, nil, nil),
				address("g1proposer"),
				42, // configVersion
				time.Now().Unix(),
				time.Now().Unix(),
			),
			getterFunc:    func(gv *governanceV1, id int64) any {
				return gv.GetProposerByProposalId(id)
			},
			expectedValue: "g1proposer",
		},
		{
			name:       "Get proposal type",
			proposalId: 1,
			proposal: newTestProposal(
				1,
				NewProposalStatus(governance.Config{
					VotingStartDelay: 100,
					VotingPeriod:     200,
					ExecutionDelay:   100,
					ExecutionWindow:  200,
					Quorum:           50,
				}, 1000, true, time.Now().Unix()),
				governance.NewProposalMetadata("TestTitle", "TestDesc"),
				governance.NewProposalData(governance.Text, nil, nil),
				address("g1proposer"),
				42, // configVersion
				time.Now().Unix(),
				time.Now().Unix(),
			),
			getterFunc:    func(gv *governanceV1, id int64) any {
				return gv.GetProposalTypeByProposalId(id)
			},
			expectedValue: "Text",
		},
		{
			name:          "Get non-existent proposal",
			proposalId:    999,
			proposal:      nil,
			getterFunc:    func(gv *governanceV1, id int64) any {
				return gv.GetProposerByProposalId(id)
			},
			expectedPanic: true,
			panicMessage:  "proposal(999) not found",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gv := newMockGovernance()

			if tc.proposal != nil {
				gv.addProposal(tc.proposal)
			}

			// when & then
			if tc.expectedPanic {
				uassert.PanicsContains(t, tc.panicMessage, func() {
					tc.getterFunc(gv, tc.proposalId)
				})
			} else {
				result := tc.getterFunc(gv, tc.proposalId)
				uassert.Equal(t, result, tc.expectedValue)
			}
		})
	}
}

// TestGetOldestActiveProposalSnapshotTime tests GetOldestActiveProposalSnapshotTime function.
func TestGetOldestActiveProposalSnapshotTime(t *testing.T) {
	baseTime := time.Now().Unix()

	tests := []struct {
		name                   string
		setupProposals         func(gv *governanceV1)
		expectedSnapshotTime   int64
		expectedHasActiveProposal bool
	}{
		{
			name: "no proposals returns false",
			setupProposals: func(gv *governanceV1) {
				// No proposals added
			},
			expectedSnapshotTime:   0,
			expectedHasActiveProposal: false,
		},
		{
			name: "single active proposal returns its snapshotTime",
			setupProposals: func(gv *governanceV1) {
				// Create an active proposal (upcoming status - before voting starts)
				config := governance.Config{
					VotingStartDelay: 3600,  // 1 hour delay
					VotingPeriod:     86400, // 1 day
					ExecutionDelay:   3600,
					ExecutionWindow:  86400,
					Quorum:           50,
				}
				status := NewProposalStatus(config, 100_000_000, true, baseTime)
				proposalID := gv.nextProposalID()
				proposal := governance.NewProposal(
					proposalID,
					status,
					governance.NewProposalMetadata("Test", "Test proposal"),
					governance.NewProposalData(governance.Text, nil, nil),
					address("g1proposer"),
					1,
					baseTime-1000, // snapshotTime: 1000 seconds ago
					baseTime,
					100,
				)
				gv.addProposal(proposal)
			},
			expectedSnapshotTime:   baseTime - 1000,
			expectedHasActiveProposal: true,
		},
		{
			name: "multiple active proposals returns oldest snapshotTime",
			setupProposals: func(gv *governanceV1) {
				config := governance.Config{
					VotingStartDelay: 3600,
					VotingPeriod:     86400,
					ExecutionDelay:   3600,
					ExecutionWindow:  86400,
					Quorum:           50,
				}

				// Proposal 1: snapshotTime = baseTime - 2000 (oldest)
				status1 := NewProposalStatus(config, 100_000_000, true, baseTime)
				proposalID1 := gv.nextProposalID()
				proposal1 := governance.NewProposal(
					proposalID1,
					status1,
					governance.NewProposalMetadata("Test1", "Test proposal 1"),
					governance.NewProposalData(governance.Text, nil, nil),
					address("g1proposer1"),
					1,
					baseTime-2000, // oldest snapshotTime
					baseTime,
					100,
				)
				gv.addProposal(proposal1)

				// Proposal 2: snapshotTime = baseTime - 500 (newer)
				status2 := NewProposalStatus(config, 100_000_000, true, baseTime)
				proposalID2 := gv.nextProposalID()
				proposal2 := governance.NewProposal(
					proposalID2,
					status2,
					governance.NewProposalMetadata("Test2", "Test proposal 2"),
					governance.NewProposalData(governance.Text, nil, nil),
					address("g1proposer2"),
					1,
					baseTime-500, // newer snapshotTime
					baseTime,
					101,
				)
				gv.addProposal(proposal2)
			},
			expectedSnapshotTime:   baseTime - 2000, // should return oldest
			expectedHasActiveProposal: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			store := newMockGovernanceStore()
			gv := &governanceV1{store: store, stakerAccessor: newMockGovStakerAccessor()}

			tc.setupProposals(gv)

			// when
			snapshotTime, hasActive := gv.GetOldestActiveProposalSnapshotTime()

			// then
			uassert.Equal(t, tc.expectedHasActiveProposal, hasActive)
			if tc.expectedHasActiveProposal {
				uassert.Equal(t, tc.expectedSnapshotTime, snapshotTime)
			}
		})
	}
}
