package staker

import (
	"std"
)

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
type DelegationManager struct {
	// userDelegations maps delegator address -> delegatee address -> list of delegation IDs
	// This nested mapping allows efficient retrieval of delegations by both delegator and delegatee
	userDelegations map[string]map[string][]int64
}

// GetUserDelegationIDsWithDelegatee retrieves all delegation IDs for a specific delegator-delegatee pair.
// This method is used to find delegations from a specific user to a specific delegate.
//
// Parameters:
//   - delegator: address of the user who delegated tokens
//   - delegatee: address of the user who received the delegation
//
// Returns:
//   - []int64: list of delegation IDs for the specified pair
func (dm *DelegationManager) GetUserDelegationIDsWithDelegatee(delegator std.Address, delegatee std.Address) []int64 {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	return dm.userDelegations[delegatorAddress][delegateeAddress]
}

// GetUserDelegationIDs retrieves all delegation IDs for a specific delegator across all delegatees.
// This method is used to find all delegations made by a specific user.
//
// Parameters:
//   - delegator: address of the user whose delegations to retrieve
//
// Returns:
//   - []int64: list of all delegation IDs for the delegator
func (dm *DelegationManager) GetUserDelegationIDs(delegator std.Address) []int64 {
	delegatorAddress := delegator.String()
	delegationIDs := make([]int64, 0)

	// Return empty slice if no delegations exist for this user
	if dm.userDelegations[delegatorAddress] == nil {
		return delegationIDs
	}

	// Collect delegation IDs from all delegatees
	for _, toDelegations := range dm.userDelegations[delegatorAddress] {
		delegationIDs = append(delegationIDs, toDelegations...)
	}

	return delegationIDs
}

// addDelegation adds a delegation ID to the manager's tracking system.
// This method creates the necessary nested map structure if it doesn't exist
// and ensures no duplicate delegation IDs are stored.
//
// Parameters:
//   - delegator: address of the user who made the delegation
//   - delegatee: address of the user who received the delegation
//   - delegationID: unique identifier for the delegation
func (dm *DelegationManager) addDelegation(delegator, delegatee std.Address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	// Initialize delegator map if it doesn't exist
	if _, ok := dm.userDelegations[delegatorAddress]; !ok {
		dm.userDelegations[delegatorAddress] = make(map[string][]int64)
	}

	// Initialize delegatee slice if it doesn't exist
	if _, ok := dm.userDelegations[delegatorAddress][delegateeAddress]; !ok {
		dm.userDelegations[delegatorAddress][delegateeAddress] = make([]int64, 0)
	}

	// Check for duplicate delegation IDs before adding
	delegationIDs := dm.userDelegations[delegatorAddress][delegateeAddress]
	for _, id := range delegationIDs {
		if id == delegationID {
			return
		}
	}

	// Add the new delegation ID
	dm.userDelegations[delegatorAddress][delegateeAddress] = append(
		delegationIDs,
		delegationID,
	)
}

// removeDelegation removes a delegation ID from the manager's tracking system.
// This method finds and removes the specified delegation ID from the appropriate slice.
//
// Parameters:
//   - delegator: address of the user who made the delegation
//   - delegatee: address of the user who received the delegation
//   - delegationID: unique identifier for the delegation to remove
func (dm *DelegationManager) removeDelegation(delegator, delegatee std.Address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	// Check if delegator exists in the map
	userDelegations, ok := dm.userDelegations[delegatorAddress]
	if !ok {
		return
	}

	// Check if delegatee exists for this delegator
	delegationIDs, ok := userDelegations[delegateeAddress]
	if !ok {
		return
	}

	index := -1

	// Find the index of the delegation ID to remove
	for i, id := range delegationIDs {
		if id == delegationID {
			index = i
			break
		}
	}

	// Remove the delegation ID if found
	if index != -1 {
		dm.userDelegations[delegatorAddress][delegateeAddress] = append(
			delegationIDs[:index],
			delegationIDs[index+1:]...,
		)
	}
}

// NewDelegationManager creates a new instance of DelegationManager.
// This factory function initializes the nested map structure for tracking user delegations.
//
// Returns:
//   - *DelegationManager: initialized delegation manager instance
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: make(map[string]map[string][]int64),
	}
}
