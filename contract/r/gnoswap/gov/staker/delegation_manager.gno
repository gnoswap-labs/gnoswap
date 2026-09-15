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
//
// Returns:
//   - *DelegationManager: manager ready to track delegator/delegatee ID lists.
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: bptree.NewBPTreeN(16),
	}
}

// GetUserDelegations returns the entire user delegations tree.
//
// Returns:
//   - *bptree.BPTree: tree keyed by delegator address string.
func (dm *DelegationManager) GetUserDelegations() *bptree.BPTree {
	return dm.userDelegations
}

// SetUserDelegations replaces the root delegator-to-delegations tree.
//
// Parameters:
//   - userDelegations: tree keyed by delegator address string and containing delegatee trees.
func (dm *DelegationManager) SetUserDelegations(userDelegations *bptree.BPTree) {
	dm.userDelegations = userDelegations
}

// GetDelegatorDelegations returns the delegatee tree for one delegator.
//
// Parameters:
//   - delegator: delegator address string used as the root-tree key.
//
// Returns:
//   - *bptree.BPTree: delegatee-to-delegation-ID tree when present and correctly typed.
//   - bool: true when the delegator entry exists with the expected tree type.
func (dm *DelegationManager) GetDelegatorDelegations(delegator string) (*bptree.BPTree, bool) {
	delegations := dm.userDelegations.Get(delegator)
	if delegations == nil {
		return nil, false
	}
	delegationsTree, ok := delegations.(*bptree.BPTree)
	if !ok {
		return nil, false
	}
	return delegationsTree, true
}

// GetDelegationIDs returns IDs recorded for one delegator/delegatee pair.
//
// Parameters:
//   - delegator: delegator address string used to select the nested tree.
//   - delegatee: delegatee address string used as the nested-tree key.
//
// Returns:
//   - []int64: delegation IDs stored for the pair.
//   - bool: true when the pair exists with a valid ID slice.
func (dm *DelegationManager) GetDelegationIDs(delegator, delegatee string) ([]int64, bool) {
	delegations, exists := dm.GetDelegatorDelegations(delegator)
	if !exists {
		return nil, false
	}
	ids := delegations.Get(delegatee)
	if ids == nil {
		return nil, false
	}
	idsSlice, ok := ids.([]int64)
	if !ok {
		return nil, false
	}
	return idsSlice, true
}

// SetDelegationIDs stores the complete ID slice for a delegator/delegatee pair.
// A missing delegator entry is initialized with a new nested tree.
//
// Parameters:
//   - delegator: delegator address string used to select or create the nested tree.
//   - delegatee: delegatee address string used as the nested-tree key.
//   - ids: delegation IDs to store for the pair.
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
//
// Parameters:
//   - delegator: delegator address string used to select the nested tree.
//   - delegatee: delegatee address string used as the nested-tree key.
//   - delegationID: delegation ID to append when it is not already present.
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
// RemoveDelegationID removes one ID from a delegator/delegatee pair.
// Missing pairs and IDs are left unchanged.
//
// Parameters:
//   - delegator: delegator address string used to select the nested tree.
//   - delegatee: delegatee address string used as the nested-tree key.
//   - delegationID: delegation ID to remove when it is present.
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
