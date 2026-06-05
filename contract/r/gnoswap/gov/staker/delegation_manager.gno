package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
type DelegationManager struct {
	// userDelegations maps delegator address -> *bptree.BPTree (delegatee address -> list of delegation IDs)
	// Using BPTree instead of map to handle unbounded growth of delegators efficiently
	userDelegations *bptree.BPTree
}

// NewDelegationManager creates a new instance of DelegationManager.
// This factory function initializes the BPTree structure for tracking user delegations.
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: bptree.NewBPTreeN(16),
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
		delegations = NewDelegationTree()
		dm.userDelegations.Set(delegator, delegations)
	}
	delegations.Set(delegatee, ids)
}

// AddDelegationID appends a delegation ID to the delegator-delegatee pair,
// skipping duplicates. The whole get-modify-set runs inside this domain method
// so the nested BPTree mutation never escapes the owning realm. Performing the
// lookup in one realm and the write in another (e.g. re-fetching the inner tree
// across a realm boundary and mutating it) would hit the cross-realm write
// guard for the persisted leaf slot.
func (dm *DelegationManager) AddDelegationID(delegator, delegatee string, delegationID int64) {
	ids, _ := dm.GetDelegationIDs(delegator, delegatee)
	for _, id := range ids {
		if id == delegationID {
			return
		}
	}
	ids = append(ids, delegationID)
	dm.SetDelegationIDs(delegator, delegatee, ids)
}

// RemoveDelegationID removes a delegation ID from the delegator-delegatee pair.
// Like AddDelegationID, the read-modify-write is kept inside this domain method.
func (dm *DelegationManager) RemoveDelegationID(delegator, delegatee string, delegationID int64) {
	ids, exists := dm.GetDelegationIDs(delegator, delegatee)
	if !exists {
		return
	}
	index := -1
	for i, id := range ids {
		if id == delegationID {
			index = i
			break
		}
	}
	if index == -1 {
		return
	}
	ids = append(ids[:index], ids[index+1:]...)
	dm.SetDelegationIDs(delegator, delegatee, ids)
}
