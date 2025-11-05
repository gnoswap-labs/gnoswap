package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestProposalManager_AddAndRemoveProposal tests adding and removing proposals
func TestProposalManager_AddAndRemoveProposal(t *testing.T) {
	tests := []struct {
		name           string
		user           address
		proposalID     int64
		proposalCount  int
		operation      string // "add" or "remove"
		expectedCount  int
		expectedExists bool
	}{
		{
			name:           "Success - Add new proposal",
			user:           address("g1user1"),
			proposalID:     2,
			proposalCount:  1,
			operation:      "add",
			expectedCount:  2,
			expectedExists: true,
		},
		{
			name:           "Success - Add multiple proposals",
			user:           address("g1user1"),
			proposalID:     3,
			proposalCount:  2,
			operation:      "add",
			expectedCount:  3,
			expectedExists: true,
		},
		{
			name:           "Success - Remove existing proposal",
			user:           address("g1user1"),
			proposalID:     1,
			proposalCount:  1,
			operation:      "remove",
			expectedCount:  0,
			expectedExists: false,
		},
		{
			name:           "Success - Remove non-existent proposal",
			user:           address("g1user2"),
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
				pm.addProposal(tc.user, int64(i+1))
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
		user          address
		proposals     []int64
		expectedCount int
	}{
		{
			name:          "Success - Get multiple proposals",
			user:          address("g1user1"),
			proposals:     []int64{1, 2, 3},
			expectedCount: 3,
		},
		{
			name:          "Success - Get empty proposals",
			user:          address("g1user2"),
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

// TestProposalManager_EdgeCases tests edge cases for proposal manager
func TestProposalManager_EdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		setup         func(*ProposalManager)
		verify        func(*testing.T, *ProposalManager)
	}{
		{
			name: "Add duplicate proposal for same user",
			setup: func(pm *ProposalManager) {
				user := address("g1user")
				pm.addProposal(user, 1)
				pm.addProposal(user, 1) // Duplicate
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				user := address("g1user")
				proposals := pm.GetUserProposals(user)
				// Map implementation will only store one instance
				uassert.Equal(t, len(proposals), 1)
				uassert.True(t, pm.HasProposal(user, 1))
			},
		},
		{
			name: "Multiple users with multiple proposals",
			setup: func(pm *ProposalManager) {
				user1 := address("g1user1")
				user2 := address("g1user2")
				user3 := address("g1user3")

				// User1: 3 proposals
				pm.addProposal(user1, 1)
				pm.addProposal(user1, 2)
				pm.addProposal(user1, 3)

				// User2: 2 proposals
				pm.addProposal(user2, 4)
				pm.addProposal(user2, 5)

				// User3: 1 proposal
				pm.addProposal(user3, 6)
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				user1 := address("g1user1")
				user2 := address("g1user2")
				user3 := address("g1user3")

				uassert.Equal(t, len(pm.GetUserProposals(user1)), 3)
				uassert.Equal(t, len(pm.GetUserProposals(user2)), 2)
				uassert.Equal(t, len(pm.GetUserProposals(user3)), 1)

				// Verify each user only has their proposals
				uassert.True(t, pm.HasProposal(user1, 1))
				uassert.False(t, pm.HasProposal(user1, 4))
				uassert.True(t, pm.HasProposal(user2, 4))
				uassert.False(t, pm.HasProposal(user2, 1))
			},
		},
		{
			name: "Remove from empty user",
			setup: func(pm *ProposalManager) {
				user := address("g1user")
				pm.removeProposal(user, 999)
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				user := address("g1user")
				proposals := pm.GetUserProposals(user)
				uassert.Equal(t, len(proposals), 0)
			},
		},
		{
			name: "HasProposal with non-existent user",
			setup: func(pm *ProposalManager) {
				// Add proposal for user1
				pm.addProposal(address("g1user1"), 1)
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				// Check for different user
				uassert.False(t, pm.HasProposal(address("g1user2"), 1))
			},
		},
		{
			name: "Add and remove all proposals for user",
			setup: func(pm *ProposalManager) {
				user := address("g1user")
				pm.addProposal(user, 1)
				pm.addProposal(user, 2)
				pm.addProposal(user, 3)
				pm.removeProposal(user, 1)
				pm.removeProposal(user, 2)
				pm.removeProposal(user, 3)
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				user := address("g1user")
				proposals := pm.GetUserProposals(user)
				uassert.Equal(t, len(proposals), 0)
				uassert.False(t, pm.HasProposal(user, 1))
				uassert.False(t, pm.HasProposal(user, 2))
				uassert.False(t, pm.HasProposal(user, 3))
			},
		},
		{
			name: "Large number of proposals for single user",
			setup: func(pm *ProposalManager) {
				user := address("g1user")
				for i := int64(1); i <= 100; i++ {
					pm.addProposal(user, i)
				}
			},
			verify: func(t *testing.T, pm *ProposalManager) {
				user := address("g1user")
				proposals := pm.GetUserProposals(user)
				uassert.Equal(t, len(proposals), 100)
				// Verify first and last
				uassert.True(t, pm.HasProposal(user, 1))
				uassert.True(t, pm.HasProposal(user, 100))
				uassert.False(t, pm.HasProposal(user, 101))
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pm := NewProposalManager()

			// when
			tc.setup(pm)

			// then
			tc.verify(t, pm)
		})
	}
}
