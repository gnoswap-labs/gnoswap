package v1

// ProposalManager manages the association between users and their created proposals.
// This structure provides efficient lookup of proposals by user address and maintains
// the relationship for governance operations and queries.
type ProposalManager struct {
	userProposals map[string]map[int64]bool // Maps user address to their proposal IDs
}

// GetUserProposals retrieves all proposal IDs created by a specific user.
// Returns an empty slice if the user has no proposals.
func (pm *ProposalManager) GetUserProposals(user address) []int64 {
	userAddress := user.String()
	proposalIds := make([]int64, 0)

	// Check if user has any proposals
	_, ok := pm.userProposals[userAddress]
	if !ok {
		return proposalIds
	}

	// Collect all proposal IDs for this user
	for proposalID := range pm.userProposals[userAddress] {
		proposalIds = append(proposalIds, proposalID)
	}

	return proposalIds
}

// HasProposal checks if a specific user has created a specific proposal.
// Returns true if the user created the specified proposal.
func (pm *ProposalManager) HasProposal(user address, proposalID int64) bool {
	userAddress := user.String()

	// First check if user has any proposals
	proposals, ok := pm.userProposals[userAddress]
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
func (pm *ProposalManager) addProposal(user address, proposalID int64) {
	userAddress := user.String()

	// Initialize user's proposal map if it doesn't exist
	if _, ok := pm.userProposals[userAddress]; !ok {
		pm.userProposals[userAddress] = make(map[int64]bool)
	}

	// Add the proposal to the user's list
	pm.userProposals[userAddress][proposalID] = true
}

// removeProposal removes the association between a user and proposal.
// This could be used for cleanup operations (though currently not used in practice).
//
// Parameters:
//   - user: address of the proposal creator
//   - proposalID: ID of the proposal to remove
func (pm *ProposalManager) removeProposal(user address, proposalID int64) {
	userAddress := user.String()

	// Exit early if user doesn't have the proposal
	if !pm.HasProposal(user, proposalID) {
		return
	}

	// Double-check user exists (defensive programming)
	if _, ok := pm.userProposals[userAddress]; !ok {
		return
	}

	// Remove the proposal from user's list
	delete(pm.userProposals[userAddress], proposalID)
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
