package staker

import (
	"std"
)

type DelegationManager struct {
	// from -> to -> delegationIDs
	userDelegations map[string]map[string][]int64
}

func (dm *DelegationManager) GetUserDelegationIDsWithDelegatee(delegator std.Address, delegatee std.Address) []int64 {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	return dm.userDelegations[delegatorAddress][delegateeAddress]
}

func (dm *DelegationManager) GetUserDelegationIDs(delegator std.Address) []int64 {
	delegatorAddress := delegator.String()
	delegationIDs := make([]int64, 0)

	if dm.userDelegations[delegatorAddress] == nil {
		return delegationIDs
	}

	for _, toDelegations := range dm.userDelegations[delegatorAddress] {
		delegationIDs = append(delegationIDs, toDelegations...)
	}

	return delegationIDs
}

func (dm *DelegationManager) addDelegation(delegator, delegatee std.Address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	if _, ok := dm.userDelegations[delegatorAddress]; !ok {
		dm.userDelegations[delegatorAddress] = make(map[string][]int64)
	}

	if _, ok := dm.userDelegations[delegatorAddress][delegateeAddress]; !ok {
		dm.userDelegations[delegatorAddress][delegateeAddress] = make([]int64, 0)
	}

	delegationIDs := dm.userDelegations[delegatorAddress][delegateeAddress]
	for _, id := range delegationIDs {
		if id == delegationID {
			return
		}
	}

	dm.userDelegations[delegatorAddress][delegateeAddress] = append(
		delegationIDs,
		delegationID,
	)
}

func (dm *DelegationManager) removeDelegation(delegator, delegatee std.Address, delegationID int64) {
	delegatorAddress := delegator.String()
	delegateeAddress := delegatee.String()

	userDelegations, ok := dm.userDelegations[delegatorAddress]
	if !ok {
		return
	}

	delegationIDs, ok := userDelegations[delegateeAddress]
	if !ok {
		return
	}

	index := -1

	for i, id := range delegationIDs {
		if id == delegationID {
			index = i
			break
		}
	}

	if index != -1 {
		dm.userDelegations[delegatorAddress][delegateeAddress] = append(
			delegationIDs[:index],
			delegationIDs[index+1:]...,
		)
	}
}

func NewDelegationManager() *DelegationManager {
	return &DelegationManager{
		userDelegations: make(map[string]map[string][]int64),
	}
}
