package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestInstance_NewGovernanceV1 tests the creation of governance v1 instance
func TestInstance_NewGovernanceV1(t *testing.T) {
	// given
	store := createMockGovernanceStore()

	// when
	impl := NewGovernanceV1(store, newMockGovStakerAccessor())

	// then
	uassert.NotNil(t, impl)

	// Verify it implements IGovernance interface
	_, ok := impl.(governance.IGovernance)
	uassert.True(t, ok)

	// Verify internal structure by type assertion
	gv, ok := impl.(*governanceV1)
	uassert.True(t, ok)
	uassert.NotNil(t, gv.store)

	// Verify store methods are accessible
	counter := gv.store.GetProposalCounter()
	uassert.NotNil(t, counter)
}

// TestInstance_RemoveInactiveUserProposals tests the removeInactiveUserProposals function
func TestInstance_RemoveInactiveUserProposals(t *testing.T) {
	config := governance.Config{
		VotingStartDelay: 100,
		VotingPeriod:     200,
		ExecutionDelay:   100,
		ExecutionWindow:  200,
		Quorum:           50,
	}

	proposerAddr := testutils.TestAddress("proposer")
	baseCreatedAt := int64(1000)
	expiredTime := baseCreatedAt + config.VotingStartDelay + config.VotingPeriod + config.ExecutionDelay + config.ExecutionWindow

	tests := []struct {
		name                   string
		setup                  func(gv *governanceV1)
		currentTime            int64
		expectedRemainingCount int
		expectedRemainingIDs   []int64
	}{
		{
			name:                   "No proposals for user",
			setup:                  func(gv *governanceV1) {},
			currentTime:            baseCreatedAt,
			expectedRemainingCount: 0,
			expectedRemainingIDs:   nil,
		},
		{
			name: "All proposals are active - none should be removed",
			setup: func(gv *governanceV1) {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(config, 1000, false, baseCreatedAt),
					governance.NewProposalMetadata("Test Title", "Test Description"),
					NewProposalTextData(),
					proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
				)
				gv.addProposal(proposal)
			},
			currentTime:            baseCreatedAt + config.VotingStartDelay + 50, // during voting period
			expectedRemainingCount: 1,
			expectedRemainingIDs:   []int64{1},
		},
		{
			name: "All proposals are expired - all should be removed",
			setup: func(gv *governanceV1) {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(config, 1000, false, baseCreatedAt),
					governance.NewProposalMetadata("Test Title", "Test Description"),
					NewProposalTextData(),
					proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
				)
				gv.addProposal(proposal)
			},
			currentTime:            expiredTime + 100, // after expired
			expectedRemainingCount: 0,
			expectedRemainingIDs:   nil,
		},
		{
			name: "Mixed active and inactive proposals - only inactive should be removed",
			setup: func(gv *governanceV1) {
				// Expired proposal
				oldProposal := governance.NewProposal(
					1,
					NewProposalStatus(config, 1000, false, baseCreatedAt),
					governance.NewProposalMetadata("Old Title", "Old Description"),
					NewProposalTextData(),
					proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
				)
				gv.addProposal(oldProposal)

				// Active proposal (created after first one expired)
				newCreatedAt := expiredTime + 50
				newProposal := governance.NewProposal(
					2,
					NewProposalStatus(config, 1000, false, newCreatedAt),
					governance.NewProposalMetadata("New Title", "New Description"),
					NewProposalTextData(),
					proposerAddr, 1, newCreatedAt, newCreatedAt, 200,
				)
				gv.addProposal(newProposal)
			},
			currentTime:            expiredTime + 50 + config.VotingStartDelay + 50, // during new proposal's voting period
			expectedRemainingCount: 1,
			expectedRemainingIDs:   []int64{2},
		},
		{
			name: "Canceled proposal should be removed",
			setup: func(gv *governanceV1) {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(config, 1000, true, baseCreatedAt),
					governance.NewProposalMetadata("Test Title", "Test Description"),
					NewProposalTextData(),
					proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
				)
				gv.addProposal(proposal)

				// Cancel the proposal
				proposalResolver := NewProposalResolver(proposal)
				_ = proposalResolver.cancel(baseCreatedAt+50, 100, proposerAddr)
			},
			currentTime:            baseCreatedAt + 50,
			expectedRemainingCount: 0,
			expectedRemainingIDs:   nil,
		},
		{
			name: "Multiple expired proposals - all should be removed",
			setup: func(gv *governanceV1) {
				for i := int64(1); i <= 3; i++ {
					proposal := governance.NewProposal(
						i,
						NewProposalStatus(config, 1000, false, baseCreatedAt),
						governance.NewProposalMetadata("Test Title", "Test Description"),
						NewProposalTextData(),
						proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
					)
					gv.addProposal(proposal)
				}
			},
			currentTime:            expiredTime + 100,
			expectedRemainingCount: 0,
			expectedRemainingIDs:   nil,
		},
		{
			name: "Multiple active proposals - none should be removed",
			setup: func(gv *governanceV1) {
				for i := int64(1); i <= 3; i++ {
					proposal := governance.NewProposal(
						i,
						NewProposalStatus(config, 1000, false, baseCreatedAt),
						governance.NewProposalMetadata("Test Title", "Test Description"),
						NewProposalTextData(),
						proposerAddr, 1, baseCreatedAt, baseCreatedAt, 100,
					)
					gv.addProposal(proposal)
				}
			},
			currentTime:            baseCreatedAt + config.VotingStartDelay + 50, // during voting period
			expectedRemainingCount: 3,
			expectedRemainingIDs:   []int64{1, 2, 3},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			gv := newMockGovernance()
			tc.setup(gv)

			// when
			err := gv.removeInactiveUserProposals(proposerAddr, tc.currentTime)

			// then
			uassert.Nil(t, err)

			proposals := gv.getUserProposals(proposerAddr.String())
			uassert.Equal(t, len(proposals), tc.expectedRemainingCount)

			// Verify remaining proposal IDs
			if tc.expectedRemainingIDs != nil {
				for i, expectedID := range tc.expectedRemainingIDs {
					uassert.Equal(t, proposals[i].ID(), expectedID)
				}
			}
		})
	}
}
