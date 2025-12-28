package staker

import (
	"gno.land/p/nt/avl"
)

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
// It maintains two bidirectional indexes for O(log n) lookup performance in both directions.
type DelegationManager struct {
	// userDelegations maps delegator address -> *avl.Tree (delegatee address -> list of delegation IDs)
	// Using AVL tree instead of map to handle unbounded growth of delegators efficiently
	userDelegations *avl.Tree

	// delegateeDelegations maps delegatee address -> *avl.Tree (delegator address -> list of delegation IDs)
	// Reverse index for efficient lookup of all delegators for a given delegatee
	delegateeDelegations *avl.Tree
}

// NewDelegationManager creates a new instance of DelegationManager.
// This factory function initializes both AVL tree structures for bidirectional tracking of user delegations.
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations:      avl.NewTree(),
		delegateeDelegations: avl.NewTree(),
	}
}

// GetUserDelegations returns the entire user delegations tree.
func (dm *DelegationManager) GetUserDelegations() *avl.Tree {
	return dm.userDelegations
}

// SetUserDelegations sets the entire user delegations tree.
func (dm *DelegationManager) SetUserDelegations(userDelegations *avl.Tree) {
	dm.userDelegations = userDelegations
}

// GetDelegateeDelegations returns the entire delegatee delegations tree.
func (dm *DelegationManager) GetDelegateeDelegations() *avl.Tree {
	return dm.delegateeDelegations
}

// SetDelegateeDelegations sets the entire delegatee delegations tree.
func (dm *DelegationManager) SetDelegateeDelegations(delegateeDelegations *avl.Tree) {
	dm.delegateeDelegations = delegateeDelegations
}

// GetDelegatorDelegations returns all delegations for a specific delegator.
func (dm *DelegationManager) GetDelegatorDelegations(delegator string) (*avl.Tree, bool) {
	delegations, exists := dm.userDelegations.Get(delegator)
	if !exists {
		return nil, false
	}
	delegationsTree, ok := delegations.(*avl.Tree)
	if !ok {
		return nil, false
	}
	return delegationsTree, true
}

// GetDelegateeIDs returns all delegation IDs for a specific delegator-delegatee pair.
func (dm *DelegationManager) GetDelegateeIDs(delegator, delegatee string) ([]int64, bool) {
	delegations, exists := dm.GetDelegatorDelegations(delegator)
	if !exists {
		return nil, false
	}
	ids, exists := delegations.Get(delegatee)
	if !exists {
		return nil, false
	}
	idsSlice, ok := ids.([]int64)
	if !ok {
		return nil, false
	}
	return idsSlice, true
}

// GetDelegateeDelegators returns all delegations for a specific delegatee (reverse index).
// This provides O(log n) lookup for finding all delegators for a given delegatee.
func (dm *DelegationManager) GetDelegateeDelegators(delegatee string) (*avl.Tree, bool) {
	delegators, exists := dm.delegateeDelegations.Get(delegatee)
	if !exists {
		return nil, false
	}
	delegatorsTree, ok := delegators.(*avl.Tree)
	if !ok {
		return nil, false
	}
	return delegatorsTree, true
}

// GetDelegatorIDsByDelegatee returns all delegation IDs for a specific delegatee-delegator pair (reverse lookup).
func (dm *DelegationManager) GetDelegatorIDsByDelegatee(delegatee, delegator string) ([]int64, bool) {
	delegators, exists := dm.GetDelegateeDelegators(delegatee)
	if !exists {
		return nil, false
	}
	ids, exists := delegators.Get(delegator)
	if !exists {
		return nil, false
	}
	idsSlice, ok := ids.([]int64)
	if !ok {
		return nil, false
	}
	return idsSlice, true
}

// SetDelegateeIDs sets delegation IDs for a specific delegator-delegatee pair.
// This method maintains both forward and reverse indexes for bidirectional lookup.
func (dm *DelegationManager) SetDelegateeIDs(delegator, delegatee string, ids []int64) {
	// Update forward index: delegator -> delegatee -> ids
	delegations, exists := dm.GetDelegatorDelegations(delegator)
	if !exists {
		delegations = avl.NewTree()
		dm.userDelegations.Set(delegator, delegations)
	}
	delegations.Set(delegatee, ids)

	// Update reverse index: delegatee -> delegator -> ids
	delegators, exists := dm.GetDelegateeDelegators(delegatee)
	if !exists {
		delegators = avl.NewTree()
		dm.delegateeDelegations.Set(delegatee, delegators)
	}
	delegators.Set(delegator, ids)
}