package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
type DelegationManager struct {
	// userDelegations maps delegator address -> *bptree.BPTree (delegatee address -> list of delegation IDs)
	// Using B+Tree instead of map to handle unbounded growth of delegators efficiently
	userDelegations *bptree.BPTree
}

// NewDelegationManager creates a new instance of DelegationManager.
// TODO: consider NewBPTreeN(64) — Iterate used, N=unbounded (delegators).
// persistent benchmark (N=1000): BPTree64 Get -4%, Set -3.4% vs BPTree32
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: bptree.NewBPTree32(),
	}
}

// GetUserDelegations returns the entire user delegations tree.
func (dm *DelegationManager) GetUserDelegations() *bptree.BPTree {
	return dm.userDelegations
}

// SetUserDelegations sets the entire user delegations tree.
func (dm *DelegationManager) SetUserDelegations(userDelegations *bptree.BPTree) {
	dm.userDelegations = userDelegations
}

// GetDelegatorDelegations returns all delegations for a specific delegator.
func (dm *DelegationManager) GetDelegatorDelegations(delegator string) (*bptree.BPTree, bool) {
	delegations, exists := dm.userDelegations.Get(delegator)
	if !exists {
		return nil, false
	}
	delegationsTree, ok := delegations.(*bptree.BPTree)
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
		delegations = bptree.NewBPTree32()
		dm.userDelegations.Set(delegator, delegations)
	}
	delegations.Set(delegatee, ids)
}
