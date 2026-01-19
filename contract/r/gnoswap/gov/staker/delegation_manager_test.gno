package staker

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

// TestDelegationManager_NewDelegationManager tests the DelegationManager constructor
func TestDelegationManager_NewDelegationManager(t *testing.T) {
	t.Run("Create new delegation manager", func(t *testing.T) {
		// when
		dm := NewDelegationManager()

		// then
		uassert.NotNil(t, dm)
		uassert.NotNil(t, dm.GetUserDelegations())
		uassert.Equal(t, dm.GetUserDelegations().Size(), 0)
	})
}

// TestDelegationManager_AddAndRemoveDelegation tests adding and removing delegation IDs
func TestDelegationManager_AddAndRemoveDelegation(t *testing.T) {
	tests := []struct {
		name             string
		delegator        string
		delegatee        string
		initialIDs       []int64
		addIDs           []int64
		removeIDs        []int64
		expectedFinalIDs []int64
	}{
		{
			name:             "Add first delegation",
			delegator:        "delegator1",
			delegatee:        "delegatee1",
			initialIDs:       []int64{},
			addIDs:           []int64{1},
			removeIDs:        []int64{},
			expectedFinalIDs: []int64{1},
		},
		{
			name:             "Add multiple delegations",
			delegator:        "delegator1",
			delegatee:        "delegatee1",
			initialIDs:       []int64{},
			addIDs:           []int64{1, 2, 3},
			removeIDs:        []int64{},
			expectedFinalIDs: []int64{1, 2, 3},
		},
		{
			name:             "Add and remove delegation",
			delegator:        "delegator1",
			delegatee:        "delegatee1",
			initialIDs:       []int64{1, 2, 3},
			addIDs:           []int64{},
			removeIDs:        []int64{2},
			expectedFinalIDs: []int64{1, 3},
		},
		{
			name:             "Remove all delegations",
			delegator:        "delegator1",
			delegatee:        "delegatee1",
			initialIDs:       []int64{1, 2},
			addIDs:           []int64{},
			removeIDs:        []int64{1, 2},
			expectedFinalIDs: []int64{},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			if len(tc.initialIDs) > 0 {
				dm.SetDelegationIDs(tc.delegator, tc.delegatee, tc.initialIDs)
			}

			// when - add IDs
			if len(tc.addIDs) > 0 {
				currentIDs, _ := dm.GetDelegationIDs(tc.delegator, tc.delegatee)
				newIDs := append(currentIDs, tc.addIDs...)
				dm.SetDelegationIDs(tc.delegator, tc.delegatee, newIDs)
			}

			// when - remove IDs
			if len(tc.removeIDs) > 0 {
				currentIDs, _ := dm.GetDelegationIDs(tc.delegator, tc.delegatee)
				for _, removeID := range tc.removeIDs {
					for i, id := range currentIDs {
						if id == removeID {
							currentIDs = append(currentIDs[:i], currentIDs[i+1:]...)
							break
						}
					}
				}
				dm.SetDelegationIDs(tc.delegator, tc.delegatee, currentIDs)
			}

			// then
			resultIDs, exists := dm.GetDelegationIDs(tc.delegator, tc.delegatee)
			if len(tc.expectedFinalIDs) == 0 {
				uassert.Equal(t, len(resultIDs), 0)
			} else {
				uassert.True(t, exists)
				uassert.Equal(t, len(resultIDs), len(tc.expectedFinalIDs))
				for i, expectedID := range tc.expectedFinalIDs {
					uassert.Equal(t, resultIDs[i], expectedID)
				}
			}
		})
	}
}

// TestDelegationManager_GetUserDelegationIDs tests retrieving all delegation IDs for a user
func TestDelegationManager_GetUserDelegationIDs(t *testing.T) {
	tests := []struct {
		name               string
		delegator          string
		delegations        map[string][]int64 // delegatee -> ids
		expectedTotalCount int
	}{
		{
			name:               "Get IDs for user with no delegations",
			delegator:          "delegator1",
			delegations:        map[string][]int64{},
			expectedTotalCount: 0,
		},
		{
			name:      "Get IDs for user with single delegatee",
			delegator: "delegator1",
			delegations: map[string][]int64{
				"delegatee1": {1, 2, 3},
			},
			expectedTotalCount: 3,
		},
		{
			name:      "Get IDs for user with multiple delegatees",
			delegator: "delegator1",
			delegations: map[string][]int64{
				"delegatee1": {1, 2},
				"delegatee2": {3, 4, 5},
				"delegatee3": {6},
			},
			expectedTotalCount: 6,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			for delegatee, ids := range tc.delegations {
				dm.SetDelegationIDs(tc.delegator, delegatee, ids)
			}

			// when
			delegations, exists := dm.GetDelegatorDelegations(tc.delegator)

			// then
			if tc.expectedTotalCount == 0 {
				uassert.False(t, exists)
			} else {
				uassert.True(t, exists)
				totalCount := 0
				delegations.Iterate("", "", func(key string, value interface{}) bool {
					if ids, ok := value.([]int64); ok {
						totalCount += len(ids)
					}
					return false
				})
				uassert.Equal(t, totalCount, tc.expectedTotalCount)
			}
		})
	}
}

// TestDelegationManager_SetUserDelegations tests setting entire user delegations map
func TestDelegationManager_SetUserDelegations(t *testing.T) {
	tests := []struct {
		name        string
		delegations map[string]map[string][]int64
	}{
		{
			name:        "Set empty delegations",
			delegations: make(map[string]map[string][]int64),
		},
		{
			name: "Set delegations with data",
			delegations: map[string]map[string][]int64{
				"delegator1": {
					"delegatee1": {1, 2, 3},
					"delegatee2": {4, 5},
				},
				"delegator2": {
					"delegatee3": {6},
				},
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()

			// when - convert map to AVL tree
			userDelegationsTree := avl.NewTree()
			for delegator, delegatees := range tc.delegations {
				delegateesTree := avl.NewTree()
				for delegatee, ids := range delegatees {
					delegateesTree.Set(delegatee, ids)
				}
				userDelegationsTree.Set(delegator, delegateesTree)
			}
			dm.SetUserDelegations(userDelegationsTree)

			// then
			result := dm.GetUserDelegations()
			uassert.Equal(t, result.Size(), len(tc.delegations))
			for delegator, delegatees := range tc.delegations {
				resultDelegatees, exists := result.Get(delegator)
				uassert.True(t, exists)
				resultTree, ok := resultDelegatees.(*avl.Tree)
				uassert.True(t, ok)
				uassert.Equal(t, resultTree.Size(), len(delegatees))
			}
		})
	}
}

// TestDelegationManager_GetDelegationIDs_NonExistent tests getting IDs for non-existent pairs
func TestDelegationManager_GetDelegationIDs_NonExistent(t *testing.T) {
	tests := []struct {
		name      string
		delegator string
		delegatee string
	}{
		{
			name:      "Get IDs for non-existent delegator",
			delegator: "nonexistent",
			delegatee: "delegatee1",
		},
		{
			name:      "Get IDs for non-existent delegatee",
			delegator: "delegator1",
			delegatee: "nonexistent",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			dm.SetDelegationIDs("delegator1", "delegatee1", []int64{1, 2, 3})

			// when
			ids, exists := dm.GetDelegationIDs(tc.delegator, tc.delegatee)

			// then
			uassert.False(t, exists)
			uassert.Equal(t, len(ids), 0)
		})
	}
}
