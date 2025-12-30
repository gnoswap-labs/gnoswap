package staker

// DelegationManager manages the mapping between users and their delegation IDs.
// It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.
type DelegationManager struct {
	// userDelegations maps delegator address -> delegatee address -> list of delegation IDs
	// This nested mapping allows efficient retrieval of delegations by both delegator and delegatee
	userDelegations map[string]map[string][]int64
}

// NewDelegationManager creates a new instance of DelegationManager.
// This factory function initializes the nested map structure for tracking user delegations.
func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: make(map[string]map[string][]int64),
	}
}

// GetUserDelegations returns the entire user delegations map.
func (dm *DelegationManager) GetUserDelegations() map[string]map[string][]int64 {
	return dm.userDelegations
}

// SetUserDelegations sets the entire user delegations map.
func (dm *DelegationManager) SetUserDelegations(userDelegations map[string]map[string][]int64) {
	dm.userDelegations = userDelegations
}

// GetDelegatorDelegations returns all delegations for a specific delegator.
func (dm *DelegationManager) GetDelegatorDelegations(delegator string) (map[string][]int64, bool) {
	delegations, exists := dm.userDelegations[delegator]
	return delegations, exists
}

// GetDelegateeIDs returns all delegation IDs for a specific delegator-delegatee pair.
func (dm *DelegationManager) GetDelegateeIDs(delegator, delegatee string) ([]int64, bool) {
	if delegations, exists := dm.userDelegations[delegator]; exists {
		ids, exists := delegations[delegatee]
		return ids, exists
	}
	return nil, false
}

// SetDelegateeIDs sets delegation IDs for a specific delegator-delegatee pair.
func (dm *DelegationManager) SetDelegateeIDs(delegator, delegatee string, ids []int64) {
	if dm.userDelegations[delegator] == nil {
		dm.userDelegations[delegator] = make(map[string][]int64)
	}
	dm.userDelegations[delegator][delegatee] = ids
}