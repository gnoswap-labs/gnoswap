package staker

import (
	"gno.land/r/gnoswap/gov/staker"
)

type DelegationManagerResolver struct {
	*staker.DelegationManager
}

// NewDelegationManagerResolver creates a resolver over an existing delegation manager.
//
// Parameters:
//   - delegationManager: manager whose domain-owned delegation trees will be queried or updated.
//
// Returns:
//   - *DelegationManagerResolver: resolver exposing address-typed delegation operations.
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
//   - []int64: matching delegation IDs, or an empty slice when no pair is stored.
func (dm *DelegationManagerResolver) GetUserDelegationIDsWithDelegatee(delegator, delegatee address) []int64 {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	ids, exists := dm.GetDelegationIDs(delegatorAddress, delegateeAddress)
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
//   - []int64: concatenated delegation IDs from every stored delegatee entry, or an empty slice when absent.
func (dm *DelegationManagerResolver) GetUserDelegationIDs(delegator address) []int64 {
	delegatorAddress := delegator.String()
	delegationIDs := make([]int64, 0)

	// Get all delegations for this delegator
	delegations, exists := dm.GetDelegatorDelegations(delegatorAddress)
	if !exists {
		return delegationIDs
	}

	// Collect delegation IDs from all delegatees by iterating the BPTree
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
	// Delegate the read-modify-write to the domain method so the nested BPTree
	// mutation stays within the owning realm; splitting the get and set across
	// the realm boundary here would taint the re-fetched inner tree.
	dm.AddDelegationID(delegator.String(), delegatee.String(), delegationID)
}

// removeDelegation removes a delegation ID from the manager's tracking system.
// This method finds and removes the specified delegation ID from the appropriate slice.
//
// Parameters:
//   - delegator: address of the user who made the delegation
//   - delegatee: address of the user who received the delegation
//   - delegationID: unique identifier for the delegation to remove
func (dm *DelegationManagerResolver) removeDelegation(delegator, delegatee address, delegationID int64) {
	// Delegate the read-modify-write to the domain method so the nested BPTree
	// mutation stays within the owning realm.
	dm.RemoveDelegationID(delegator.String(), delegatee.String(), delegationID)
}
