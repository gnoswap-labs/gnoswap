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
				dm.SetDelegateeIDs(tc.delegator, tc.delegatee, tc.initialIDs)
			}

			// when - add IDs
			if len(tc.addIDs) > 0 {
				currentIDs, _ := dm.GetDelegateeIDs(tc.delegator, tc.delegatee)
				newIDs := append(currentIDs, tc.addIDs...)
				dm.SetDelegateeIDs(tc.delegator, tc.delegatee, newIDs)
			}

			// when - remove IDs
			if len(tc.removeIDs) > 0 {
				currentIDs, _ := dm.GetDelegateeIDs(tc.delegator, tc.delegatee)
				for _, removeID := range tc.removeIDs {
					for i, id := range currentIDs {
						if id == removeID {
							currentIDs = append(currentIDs[:i], currentIDs[i+1:]...)
							break
						}
					}
				}
				dm.SetDelegateeIDs(tc.delegator, tc.delegatee, currentIDs)
			}

			// then
			resultIDs, exists := dm.GetDelegateeIDs(tc.delegator, tc.delegatee)
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
		name                  string
		delegator             string
		delegations           map[string][]int64 // delegatee -> ids
		expectedTotalCount    int
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
				dm.SetDelegateeIDs(tc.delegator, delegatee, ids)
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
		name           string
		setup          func() *avl.Tree
		expectedSize   int
		verifyDelegator func(*testing.T, *avl.Tree)
	}{
		{
			name: "Set empty delegations",
			setup: func() *avl.Tree {
				return avl.NewTree()
			},
			expectedSize:   0,
			verifyDelegator: func(t *testing.T, result *avl.Tree) {},
		},
		{
			name: "Set delegations with data",
			setup: func() *avl.Tree {
				tree := avl.NewTree()

				// delegator1
				delegatee1Tree := avl.NewTree()
				delegatee1Tree.Set("delegatee1", []int64{1, 2, 3})
				delegatee1Tree.Set("delegatee2", []int64{4, 5})
				tree.Set("delegator1", delegatee1Tree)

				// delegator2
				delegatee2Tree := avl.NewTree()
				delegatee2Tree.Set("delegatee3", []int64{6})
				tree.Set("delegator2", delegatee2Tree)

				return tree
			},
			expectedSize: 2,
			verifyDelegator: func(t *testing.T, result *avl.Tree) {
				// Verify delegator1
				val, exists := result.Get("delegator1")
				uassert.True(t, exists)
				delegator1Tree, ok := val.(*avl.Tree)
				uassert.True(t, ok)
				uassert.Equal(t, delegator1Tree.Size(), 2)

				// Verify delegator2
				val, exists = result.Get("delegator2")
				uassert.True(t, exists)
				delegator2Tree, ok := val.(*avl.Tree)
				uassert.True(t, ok)
				uassert.Equal(t, delegator2Tree.Size(), 1)
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()

			// when
			dm.SetUserDelegations(tc.setup())

			// then
			result := dm.GetUserDelegations()
			uassert.Equal(t, result.Size(), tc.expectedSize)
			tc.verifyDelegator(t, result)
		})
	}
}

// TestDelegationManager_GetDelegateeIDs_NonExistent tests getting IDs for non-existent pairs
func TestDelegationManager_GetDelegateeIDs_NonExistent(t *testing.T) {
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
			dm.SetDelegateeIDs("delegator1", "delegatee1", []int64{1, 2, 3})

			// when
			ids, exists := dm.GetDelegateeIDs(tc.delegator, tc.delegatee)

			// then
			uassert.False(t, exists)
			uassert.Equal(t, len(ids), 0)
		})
	}
}

// TestDelegationManager_BidirectionalIndex tests that both forward and reverse indexes are maintained
func TestDelegationManager_BidirectionalIndex(t *testing.T) {
	tests := []struct {
		name                    string
		delegations             map[string]map[string][]int64 // delegator -> delegatee -> ids
		verifyDelegatee         string
		expectedDelegatorsCount int
		expectedTotalIDs        int
	}{
		{
			name: "Single delegator to single delegatee",
			delegations: map[string]map[string][]int64{
				"delegator1": {
					"delegatee1": {1, 2, 3},
				},
			},
			verifyDelegatee:         "delegatee1",
			expectedDelegatorsCount: 1,
			expectedTotalIDs:        3,
		},
		{
			name: "Multiple delegators to single delegatee",
			delegations: map[string]map[string][]int64{
				"delegator1": {
					"delegatee1": {1, 2},
				},
				"delegator2": {
					"delegatee1": {3, 4, 5},
				},
				"delegator3": {
					"delegatee1": {6},
				},
			},
			verifyDelegatee:         "delegatee1",
			expectedDelegatorsCount: 3,
			expectedTotalIDs:        6,
		},
		{
			name: "Delegator delegates to multiple delegatees",
			delegations: map[string]map[string][]int64{
				"delegator1": {
					"delegatee1": {1, 2},
					"delegatee2": {3, 4},
				},
			},
			verifyDelegatee:         "delegatee1",
			expectedDelegatorsCount: 1,
			expectedTotalIDs:        2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			for delegator, delegatees := range tc.delegations {
				for delegatee, ids := range delegatees {
					dm.SetDelegateeIDs(delegator, delegatee, ids)
				}
			}

			// when - verify reverse index
			delegators, exists := dm.GetDelegateeDelegators(tc.verifyDelegatee)

			// then
			uassert.True(t, exists)
			uassert.Equal(t, delegators.Size(), tc.expectedDelegatorsCount)

			// verify total IDs count
			totalIDs := 0
			delegators.Iterate("", "", func(key string, value interface{}) bool {
				if ids, ok := value.([]int64); ok {
					totalIDs += len(ids)
				}
				return false
			})
			uassert.Equal(t, totalIDs, tc.expectedTotalIDs)

			// verify forward index still works
			for delegator, delegatees := range tc.delegations {
				for delegatee, expectedIDs := range delegatees {
					ids, exists := dm.GetDelegateeIDs(delegator, delegatee)
					uassert.True(t, exists)
					uassert.Equal(t, len(ids), len(expectedIDs))
				}
			}
		})
	}
}

// TestDelegationManager_GetDelegatorIDsByDelegatee tests reverse lookup functionality
func TestDelegationManager_GetDelegatorIDsByDelegatee(t *testing.T) {
	tests := []struct {
		name        string
		delegator   string
		delegatee   string
		ids         []int64
		shouldExist bool
	}{
		{
			name:        "Get IDs for existing delegatee-delegator pair",
			delegator:   "delegator1",
			delegatee:   "delegatee1",
			ids:         []int64{1, 2, 3},
			shouldExist: true,
		},
		{
			name:        "Get IDs for non-existent delegatee",
			delegator:   "delegator1",
			delegatee:   "nonexistent",
			ids:         []int64{},
			shouldExist: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			if tc.shouldExist {
				dm.SetDelegateeIDs(tc.delegator, tc.delegatee, tc.ids)
			}

			// when
			ids, exists := dm.GetDelegatorIDsByDelegatee(tc.delegatee, tc.delegator)

			// then
			uassert.Equal(t, exists, tc.shouldExist)
			if tc.shouldExist {
				uassert.Equal(t, len(ids), len(tc.ids))
				for i, expectedID := range tc.ids {
					uassert.Equal(t, ids[i], expectedID)
				}
			}
		})
	}
}
