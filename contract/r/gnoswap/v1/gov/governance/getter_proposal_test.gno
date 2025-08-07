package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"
)

// TestGetterProposal_All tests all getter functions related to Proposal using table-driven tests.
func TestGetterProposal_All(t *testing.T) {
	tests := []struct {
		name           string
		proposalId     int64
		proposal  *Proposal
		getterFunc     func(int64) interface{}
		expectedValue  interface{}
		expectedPanic  bool
		panicMessage   string
	}{
		{
			name:       "Get proposer address",
			proposalId: 1,
			proposal: &Proposal{
				id:            1,
				proposer:      std.Address("g1proposer"),
				configVersion: 42,
				status: &ProposalStatus{
					voteStatus: &ProposalVoteStatus{
						quorumAmount: 100,
						yea:         10,
						nay:         5,
					},
				},
				metadata: &ProposalMetadata{title: "TestTitle", description: "TestDesc"},
				data:     &ProposalData{proposalType: Text},
			},
			getterFunc:    func(id int64) interface{} { return GetProposerByProposalId(id) },
			expectedValue: "g1proposer",
		},
		{
			name:       "Get proposal type",
			proposalId: 1,
			proposal: &Proposal{
				id:            1,
				proposer:      std.Address("g1proposer"),
				configVersion: 42,
				status: &ProposalStatus{
					voteStatus: &ProposalVoteStatus{
						quorumAmount: 100,
						yea:         10,
						nay:         5,
					},
				},
				metadata: &ProposalMetadata{title: "TestTitle", description: "TestDesc"},
				data:     &ProposalData{proposalType: Text},
			},
			getterFunc:    func(id int64) interface{} { return GetProposalTypeByProposalId(id) },
			expectedValue: "Text",
		},
		{
			name:          "Get non-existent proposal",
			proposalId:    999,
			proposal: nil,
			getterFunc:    func(id int64) interface{} { return GetProposerByProposalId(id) },
			expectedPanic: true,
			panicMessage: "[GNOSWAP-GOVERNANCE-003] requested data not found",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			proposals = avl.NewTree() // reset proposals state
			proposalManager = NewProposalManager() // reset proposalManager state

			if tc.proposal != nil {
				addProposal(tc.proposal)
			}

			// when & then
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.panicMessage, func() {
					tc.getterFunc(tc.proposalId)
				})
			} else {
				result := tc.getterFunc(tc.proposalId)
				uassert.Equal(t, result, tc.expectedValue)
			}
		})
	}
} 