package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type DelegationManagerResolver struct {
	*staker.DelegationManager
}

func NewDelegationManagerResolver(delegationManager *staker.DelegationManager) *DelegationManagerResolver {
	return &DelegationManagerResolver{delegationManager}
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
func (dm *DelegationManagerResolver) GetUserDelegationIDsWithDelegatee(delegator, delegatee address) []int64 {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	ids, exists := dm.GetDelegateeIDs(delegatorAddress, delegateeAddress)
	if !exists {
		return []int64{}
	}
	return ids
}

// GetUserDelegationIDs retrieves all delegation IDs for a specific delegator across all delegatees.
// This method is used to find all delegations made by a specific user.
//
// Parameters:
//   - delegator: address of the user whose delegations to retrieve
//
// Returns:
//   - []int64: list of all delegation IDs for the delegator
func (dm *DelegationManagerResolver) GetUserDelegationIDs(delegator address) []int64 {
	delegatorAddress := delegator.String()
	delegationIDs := make([]int64, 0)

	// Get all delegations for this delegator
	delegations, exists := dm.GetDelegatorDelegations(delegatorAddress)
	if !exists {
		return delegationIDs
	}

	// Collect delegation IDs from all delegatees by iterating the AVL tree
	delegations.Iterate("", "", func(key string, value interface{}) bool {
		if toDelegations, ok := value.([]int64); ok {
			delegationIDs = append(delegationIDs, toDelegations...)
		}
		return false
	})

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
func (dm *DelegationManagerResolver) addDelegation(delegator, delegatee address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	// Get existing IDs
	ids, _ := dm.GetDelegateeIDs(delegatorAddress, delegateeAddress)

	// Check for duplicates
	for _, id := range ids {
		if id == delegationID {
			return
		}
	}

	// Add the new delegation ID
	ids = append(ids, delegationID)
	dm.SetDelegateeIDs(delegatorAddress, delegateeAddress, ids)
}

// removeDelegation removes a delegation ID from the manager's tracking system.
// This method finds and removes the specified delegation ID from the appropriate slice.
//
// Parameters:
//   - delegator: address of the user who made the delegation
//   - delegatee: address of the user who received the delegation
//   - delegationID: unique identifier for the delegation to remove
func (dm *DelegationManagerResolver) removeDelegation(delegator, delegatee address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	// Get existing IDs
	ids, exists := dm.GetDelegateeIDs(delegatorAddress, delegateeAddress)
	if !exists {
		return
	}

	// Find and remove the delegation ID
	index := -1
	for i, id := range ids {
		if id == delegationID {
			index = i
			break
		}
	}

	// Remove the delegation ID if found
	if index != -1 {
		ids = append(ids[:index], ids[index+1:]...)
		dm.SetDelegateeIDs(delegatorAddress, delegateeAddress, ids)
	}
}
