package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestProposalManager_AddAndRemoveProposal tests adding and removing proposals
func TestProposalManager_AddAndRemoveProposal(t *testing.T) {
	tests := []struct {
		name           string
		user           std.Address
		proposalID     int64
		proposalCount  int
		operation      string // "add" or "remove"
		expectedCount  int
		expectedExists bool
	}{
		{
			name:           "Success - Add new proposal",
			user:           std.Address("g1user1"),
			proposalID:     2,
			proposalCount:  1,
			operation:      "add",
			expectedCount:  2,
			expectedExists: true,
		},
		{
			name:           "Success - Add multiple proposals",
			user:           std.Address("g1user1"),
			proposalID:     3,
			proposalCount:  2,
			operation:      "add",
			expectedCount:  3,
			expectedExists: true,
		},
		{
			name:           "Success - Remove existing proposal",
			user:           std.Address("g1user1"),
			proposalID:     1,
			proposalCount:  1,
			operation:      "remove",
			expectedCount:  0,
			expectedExists: false,
		},
		{
			name:           "Success - Remove non-existent proposal",
			user:           std.Address("g1user2"),
			proposalID:     999,
			proposalCount:  0,
			operation:      "remove",
			expectedCount:  0,
			expectedExists: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pm := NewProposalManager()
			for i := 0; i < tc.proposalCount; i++ {
				pm.addProposal(tc.user, int64(i + 1))
			}

			if tc.operation == "add" {
				pm.addProposal(tc.user, tc.proposalID)
			} else {
				pm.removeProposal(tc.user, tc.proposalID)
			}

			// when & then
			proposals := pm.GetUserProposals(tc.user)
			uassert.Equal(t, len(proposals), tc.expectedCount)
			uassert.Equal(t, pm.HasProposal(tc.user, tc.proposalID), tc.expectedExists)
		})
	}
}

// TestProposalManager_GetUserProposals tests retrieving user proposals
func TestProposalManager_GetUserProposals(t *testing.T) {
	tests := []struct {
		name          string
		user          std.Address
		proposals     []int64
		expectedCount int
	}{
		{
			name:          "Success - Get multiple proposals",
			user:          std.Address("g1user1"),
			proposals:     []int64{1, 2, 3},
			expectedCount: 3,
		},
		{
			name:          "Success - Get empty proposals",
			user:          std.Address("g1user2"),
			proposals:     []int64{},
			expectedCount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pm := NewProposalManager()
			for _, proposalID := range tc.proposals {
				pm.addProposal(tc.user, proposalID)
			}

			// when
			proposals := pm.GetUserProposals(tc.user)

			// then
			uassert.Equal(t, len(proposals), tc.expectedCount)
			for _, proposalID := range tc.proposals {
				uassert.True(t, pm.HasProposal(tc.user, proposalID))
			}
		})
	}
}

// TestNewProposalManager tests creation of new proposal manager
func TestNewProposalManager(t *testing.T) {
	// when
	pm := NewProposalManager()

	// then
	uassert.NotNil(t, pm)
	uassert.NotNil(t, pm.userProposals)
	uassert.Equal(t, len(pm.userProposals), 0)
} 