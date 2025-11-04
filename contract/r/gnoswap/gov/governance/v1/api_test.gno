package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"

	"gno.land/r/gnoswap/gov/governance"
)

// TestAPI_createVoteJsonNode tests the private createVoteJsonNode function
func TestAPI_createVoteJsonNode(t *testing.T) {
	tests := []struct {
		name               string
		addr               address
		proposalId         int64
		setupVotingInfo    func() *governance.VotingInfo
		expectedProposalId string
		expectedVoteYes    string
	}{
		{
			name:       "create JSON node for yes vote",
			addr:       testutils.TestAddress("voter1"),
			proposalId: 1,
			setupVotingInfo: func() *governance.VotingInfo {
				vote := governance.NewVotingInfo(1000, testutils.TestAddress("voter1"))
				resolver := NewVotingInfoResolver(vote)
				resolver.vote(true, 1000, 100, 1234567890)
				return vote
			},
			expectedProposalId: "1",
			expectedVoteYes:    "true",
		},
		{
			name:       "create JSON node for no vote",
			addr:       testutils.TestAddress("voter2"),
			proposalId: 2,
			setupVotingInfo: func() *governance.VotingInfo {
				vote := governance.NewVotingInfo(500, testutils.TestAddress("voter2"))
				resolver := NewVotingInfoResolver(vote)
				resolver.vote(false, 500, 200, 1234567900)
				return vote
			},
			expectedProposalId: "2",
			expectedVoteYes:    "false",
		},
		{
			name:       "create JSON node for unvoted",
			addr:       testutils.TestAddress("voter3"),
			proposalId: 3,
			setupVotingInfo: func() *governance.VotingInfo {
				return governance.NewVotingInfo(2000, testutils.TestAddress("voter3"))
			},
			expectedProposalId: "3",
			expectedVoteYes:    "false",
		},
		{
			name:       "create JSON node with zero weight",
			addr:       testutils.TestAddress("voter4"),
			proposalId: 4,
			setupVotingInfo: func() *governance.VotingInfo {
				vote := governance.NewVotingInfo(0, testutils.TestAddress("voter4"))
				resolver := NewVotingInfoResolver(vote)
				resolver.vote(true, 0, 150, 1234567950)
				return vote
			},
			expectedProposalId: "4",
			expectedVoteYes:    "true",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			votingInfo := tt.setupVotingInfo()

			// when
			node := createVoteJsonNode(tt.addr, tt.proposalId, votingInfo)

			// then
			uassert.NotNil(t, node)

			// Verify JSON node structure by marshaling and checking fields
			jsonStr := marshal(node)
			uassert.NotNil(t, jsonStr)

			// Verify it contains expected data
			if len(jsonStr) == 0 {
				t.Errorf("expected non-empty JSON string")
			}

			// Parse back to verify structure
			parsedNode, err := json.Unmarshal([]byte(jsonStr))
			uassert.Nil(t, err)
			uassert.NotNil(t, parsedNode)

			// Verify proposal ID
			proposalIdNode, err := parsedNode.GetKey("proposalId")
			uassert.Nil(t, err)
			uassert.NotNil(t, proposalIdNode)
			uassert.Equal(t, proposalIdNode.MustString(), tt.expectedProposalId)

			// Verify vote yes
			voteYesNode, err := parsedNode.GetKey("voteYes")
			uassert.Nil(t, err)
			uassert.NotNil(t, voteYesNode)
			uassert.Equal(t, voteYesNode.MustString(), tt.expectedVoteYes)

			// Verify other required fields exist
			voteWeightNode, err := parsedNode.GetKey("voteWeight")
			uassert.Nil(t, err)
			uassert.NotNil(t, voteWeightNode)

			voteHeightNode, err := parsedNode.GetKey("voteHeight")
			uassert.Nil(t, err)
			uassert.NotNil(t, voteHeightNode)

			voteTimestampNode, err := parsedNode.GetKey("voteTimestamp")
			uassert.Nil(t, err)
			uassert.NotNil(t, voteTimestampNode)
		})
	}
}

// TestAPI_metaNode tests the private metaNode function
func TestAPI_metaNode(t *testing.T) {
	// when
	node := metaNode()

	// then
	uassert.NotNil(t, node)

	// Verify JSON node structure by marshaling
	jsonStr := marshal(node)
	uassert.NotNil(t, jsonStr)

	// Parse back to verify structure
	parsedNode, err := json.Unmarshal([]byte(jsonStr))
	uassert.Nil(t, err)
	uassert.NotNil(t, parsedNode)

	// Verify height field exists
	heightNode, err := parsedNode.GetKey("height")
	uassert.Nil(t, err)
	uassert.NotNil(t, heightNode)
	height := heightNode.MustString()
	uassert.True(t, len(height) > 0)

	// Verify now field exists
	nowNode, err := parsedNode.GetKey("now")
	uassert.Nil(t, err)
	uassert.NotNil(t, nowNode)
	now := nowNode.MustString()
	uassert.True(t, len(now) > 0)
}

// TestAPI_marshal tests the private marshal function
func TestAPI_marshal(t *testing.T) {
	tests := []struct {
		name             string
		setupNode        func() *json.Node
		expectedContains string
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name: "marshal simple JSON node",
			setupNode: func() *json.Node {
				return json.Builder().
					WriteString("key1", "value1").
					WriteString("key2", "value2").
					Node()
			},
			expectedContains: "key1",
		},
		{
			name: "marshal empty JSON node",
			setupNode: func() *json.Node {
				return json.Builder().Node()
			},
			expectedContains: "",
		},
		{
			name: "marshal JSON node with numbers",
			setupNode: func() *json.Node {
				return json.Builder().
					WriteString("number", "123").
					WriteString("boolean", "true").
					Node()
			},
			expectedContains: "number",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			node := tt.setupNode()

			if tt.expectedPanic {
				// when & then
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					marshal(node)
				})
			} else {
				// when
				result := marshal(node)

				// then
				uassert.NotNil(t, result)
				if tt.expectedContains != "" {
					if !contains(result, tt.expectedContains) {
						t.Errorf("expected result to contain '%s', got '%s'", tt.expectedContains, result)
					}
				}

				// Verify it's valid JSON by unmarshaling
				_, err := json.Unmarshal([]byte(result))
				uassert.Nil(t, err)
			}
		})
	}
}

// Helper function to check if string contains substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 || findSubstring(s, substr))
}

func findSubstring(s, substr string) bool {
	if len(substr) > len(s) {
		return false
	}
	for i := 0; i <= len(s)-len(substr); i++ {
		match := true
		for j := 0; j < len(substr); j++ {
			if s[i+j] != substr[j] {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}
