package v1

import (
	"chain/runtime"
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
			proposal: governance.NewProposal(
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
				runtime.ChainHeight(),
			),
			getterFunc:    func(gv *governanceV1, id int64) any {
				return gv.GetProposerByProposalId(id)
			},
			expectedValue: "g1proposer",
		},
		{
			name:       "Get proposal type",
			proposalId: 1,
			proposal: governance.NewProposal(
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
				runtime.ChainHeight(),
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
