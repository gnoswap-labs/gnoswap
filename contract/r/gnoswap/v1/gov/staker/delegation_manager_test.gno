package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestDelegationManager_AddAndRemoveDelegation tests adding and removing delegations
func TestDelegationManager_AddAndRemoveDelegation(t *testing.T) {
	tests := []struct {
		name            string
		delegator       std.Address
		delegationID    int64
		delegationCount int
		operation       string // "add" or "remove"
		expectedCount   int
		expectedExists  bool
	}{
		{
			name:            "Add new delegation",
			delegator:       std.Address("g1delegator"),
			delegationID:    1,
			delegationCount: 0,
			operation:       "add",
			expectedCount:   1,
			expectedExists:  true,
		},
		{
			name:            "Add multiple delegations",
			delegator:       std.Address("g1delegator"),
			delegationID:    2,
			delegationCount: 1,
			operation:       "add",
			expectedCount:   2,
			expectedExists:  true,
		},
		{
			name:            "Remove existing delegation",
			delegator:       std.Address("g1delegator"),
			delegationID:    1,
			delegationCount: 2,
			operation:       "remove",
			expectedCount:   1,
			expectedExists:  false,
		},
		{
			name:            "Remove non-existent delegation",
			delegator:       std.Address("g1other"),
			delegationID:    999,
			delegationCount: 0,
			operation:       "remove",
			expectedCount:   0,
			expectedExists:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()

			for i := 0; i < tc.delegationCount; i++ {
				dm.addDelegation(tc.delegator, std.Address("g1delegatee"), int64(i+1))
			}

			if tc.operation == "add" {
				dm.addDelegation(tc.delegator, std.Address("g1delegatee"), tc.delegationID)
			} else {
				dm.removeDelegation(tc.delegator, std.Address("g1delegatee"), tc.delegationID)
			}

			// when & then
			delegations := dm.GetUserDelegationIDs(tc.delegator)
			uassert.Equal(t, len(delegations), tc.expectedCount)

			found := false
			for _, id := range delegations {
				if id == tc.delegationID {
					found = true
					break
				}
			}
			uassert.Equal(t, found, tc.expectedExists)
		})
	}
}

// TestDelegationManager_GetUserDelegationIDs tests retrieving user delegation IDs
func TestDelegationManager_GetUserDelegationIDs(t *testing.T) {
	tests := []struct {
		name          string
		delegator     std.Address
		delegationIDs []int64
		expectedCount int
	}{
		{
			name:          "Get multiple delegation IDs",
			delegator:     std.Address("g1user1"),
			delegationIDs: []int64{1, 2, 3},
			expectedCount: 3,
		},
		{
			name:          "Get empty delegation IDs",
			delegator:     std.Address("g1user2"),
			delegationIDs: []int64{},
			expectedCount: 0,
		},
		{
			name:          "Get single delegation ID",
			delegator:     std.Address("g1user3"),
			delegationIDs: []int64{10},
			expectedCount: 1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			dm := NewDelegationManager()
			for _, delegationID := range tc.delegationIDs {
				dm.addDelegation(tc.delegator, std.Address("g1delegatee"), delegationID)
			}

			// when
			delegations := dm.GetUserDelegationIDs(tc.delegator)

			// then
			uassert.Equal(t, len(delegations), tc.expectedCount)
			for _, expectedID := range tc.delegationIDs {
				found := false
				for _, actualID := range delegations {
					if actualID == expectedID {
						found = true
						break
					}
				}
				uassert.True(t, found)
			}
		})
	}
}

// TestNewDelegationManager tests creation of new delegation manager
func TestNewDelegationManager(t *testing.T) {
	// when
	dm := NewDelegationManager()

	// then
	uassert.NotNil(t, dm)
	uassert.NotNil(t, dm.userDelegations)
	uassert.Equal(t, len(dm.userDelegations), 0)

	// Test initial empty state
	delegations := dm.GetUserDelegationIDs(std.Address("g1any"))
	uassert.Equal(t, len(delegations), 0)
}
