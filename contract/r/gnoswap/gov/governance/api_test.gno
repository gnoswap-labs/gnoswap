package governance

import (
	"testing"

	"gno.land/p/demo/json"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestCreateProposalJsonNode(t *testing.T) {
	tt := []struct {
		name           string
		proposal       ProposalInfo
		expectedFields []struct {
			key      string
			expected string
		}
		expectedError error
	}{
		{
			name: "create proposal json node success",
			proposal: ProposalInfo{
				ConfigVersion: 1,
				Proposer:      testutils.TestAddress("proposal"),
				Metadata: ProposalMetadata{
					Title:       "Test Proposal",
					Description: "This is a test proposal",
				},
			},
			expectedFields: []struct {
				key      string
				expected string
			}{
				{"id", "123"},
				{"configVersion", "1"},
				{"proposer", "g1wpex7ur0wdskch6lta047h6lta047h6ljhqtj2"}, // proposal address
				{"title", "Test Proposal"},
				{"description", "This is a test proposal"},
			},
			expectedError: nil,
		},
		{
			name: "create proposal json node success with empty fields",
			proposal: ProposalInfo{
				ConfigVersion: 1,
				Proposer:      testutils.TestAddress("proposal"),
				Metadata: ProposalMetadata{
					Title:       "",
					Description: "",
				},
			},
			expectedFields: []struct {
				key      string
				expected string
			}{
				{"id", "123"},
				{"configVersion", "1"},
				{"proposer", "g1wpex7ur0wdskch6lta047h6lta047h6ljhqtj2"}, // proposal address
				{"type", ""},
				{"title", ""},
				{"description", ""},
			},
			expectedError: nil,
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := createProposalJsonNode(123, tc.proposal)

			// then
			for _, field := range tc.expectedFields {
				node, err := result.GetKey(field.key)
				uassert.NoError(t, err)

				value, err := node.GetString()
				uassert.NoError(t, err)
				uassert.Equal(t, value, field.expected)
			}
		})
	}
}

func TestGetProposalVotes(t *testing.T) {
	tt := []struct {
		name            string
		proposalId      uint64
		proposal        ProposalInfo
		inputProposalId uint64
		expectedFields  []struct {
			key      string
			expected string
		}
	}{
		{
			name:       "get proposal votes success",
			proposalId: 1,
			proposal: ProposalInfo{
				Voting: VotingInfo{
					MaxVotingWeight: u256.NewUint(1000000000000000000),
					QuorumAmount:    500000000000000000,
					Yea:             u256.NewUint(1000000000000000000),
					Nay:             u256.NewUint(0),
				},
			},
			inputProposalId: 1,
			expectedFields: []struct {
				key      string
				expected string
			}{
				{"quorum", "500000000000000000"},
				{"max", "1000000000000000000"},
				{"yes", "1000000000000000000"},
				{"no", "0"},
			},
		},
		{
			name:            "get proposal votes empty by non-existent proposal",
			proposalId:      1,
			proposal:        ProposalInfo{},
			inputProposalId: 999,
			expectedFields: []struct {
				key      string
				expected string
			}{},
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Save original state and create test state
			originalState := governanceState
			testState := NewGovernanceState(Config{})

			// Add proposal to test state
			testState = testState.WithNewProposal(tc.proposal.Proposer, tc.proposal)

			// Temporarily replace global state
			governanceState = testState

			// Restore original state after test
			defer func() {
				governanceState = originalState
			}()

			// when
			votes := getProposalVotes(tc.inputProposalId)

			jsonNode, err := json.Unmarshal([]byte(votes))
			if err != nil {
				jsonNode = json.Builder().Node()
			}

			// then
			for _, field := range tc.expectedFields {
				node, err := jsonNode.GetKey(field.key)
				uassert.NoError(t, err)

				value, err := node.GetString()
				uassert.NoError(t, err)
				uassert.Equal(t, value, field.expected)
			}
		})
	}
}
