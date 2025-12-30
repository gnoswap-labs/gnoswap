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
