package governance

import "std"

// ProposalManager manages the association between users and their created proposals.
// This structure provides efficient lookup of proposals by user address and maintains
// the relationship for governance operations and queries.
type ProposalManager struct {
	userProposals map[string]map[int64]bool // Maps user address to their proposal IDs
}

// GetUserProposals retrieves all proposal IDs created by a specific user.
// Returns an empty slice if the user has no proposals.
func (pm *ProposalManager) GetUserProposals(user std.Address) []int64 {
	// Check if user has any proposals
	_, ok := pm.userProposals[user.String()]
	if !ok {
		return []int64{}
	}

	proposalIDs := make([]int64, 0)

	// Collect all proposal IDs for this user
	for proposalID := range pm.userProposals[user.String()] {
		proposalIDs = append(proposalIDs, proposalID)
	}

	return proposalIDs
}

// HasProposal checks if a specific user has created a specific proposal.
// Returns true if the user created the specified proposal.
func (pm *ProposalManager) HasProposal(user std.Address, proposalID int64) bool {
	// First check if user has any proposals
	proposals, ok := pm.userProposals[user.String()]
	if !ok {
		return false
	}

	// Then check if specific proposal exists for this user
	_, ok = proposals[proposalID]
	if !ok {
		return false
	}

	return true
}

// addProposal associates a proposal with its creator.
// This is called when a new proposal is created to establish the relationship.
//
// Parameters:
//   - user: address of the proposal creator
//   - proposalID: ID of the created proposal
func (pm *ProposalManager) addProposal(user std.Address, proposalID int64) {
	// Initialize user's proposal map if it doesn't exist
	if _, ok := pm.userProposals[user.String()]; !ok {
		pm.userProposals[user.String()] = make(map[int64]bool)
	}

	// Add the proposal to the user's list
	pm.userProposals[user.String()][proposalID] = true
}

// removeProposal removes the association between a user and proposal.
// This could be used for cleanup operations (though currently not used in practice).
//
// Parameters:
//   - user: address of the proposal creator
//   - proposalID: ID of the proposal to remove
func (pm *ProposalManager) removeProposal(user std.Address, proposalID int64) {
	// Exit early if user doesn't have the proposal
	if !pm.HasProposal(user, proposalID) {
		return
	}

	// Double-check user exists (defensive programming)
	if _, ok := pm.userProposals[user.String()]; !ok {
		return
	}

	// Remove the proposal from user's list
	delete(pm.userProposals[user.String()], proposalID)
}

// NewProposalManager creates a new proposal manager instance.
// Initializes the internal data structures for managing user-proposal relationships.
//
// Returns:
//   - *ProposalManager: new proposal manager instance
func NewProposalManager() *ProposalManager {
	return &ProposalManager{
		userProposals: make(map[string]map[int64]bool),
	}
}
