package staker

import (
	"gno.land/p/nt/avl"
)

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
type DelegationManager struct {
	// userDelegations maps delegator address -> *avl.Tree (delegatee address -> list of delegation IDs)
	// Using AVL tree instead of map to handle unbounded growth of delegators efficiently
	userDelegations *avl.Tree
}

// NewDelegationManager creates a new instance of DelegationManager.
// This factory function initializes the AVL tree structure for tracking user delegations.
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: avl.NewTree(),
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

// GetDelegationIDs returns all delegation IDs for a specific delegator-delegatee pair.
func (dm *DelegationManager) GetDelegationIDs(delegator, delegatee string) ([]int64, bool) {
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

// SetDelegationIDs sets delegation IDs for a specific delegator-delegatee pair.
func (dm *DelegationManager) SetDelegationIDs(delegator, delegatee string, ids []int64) {
	delegations, exists := dm.GetDelegatorDelegations(delegator)
	if !exists {
		delegations = avl.NewTree()
		dm.userDelegations.Set(delegator, delegations)
	}
	delegations.Set(delegatee, ids)
}
