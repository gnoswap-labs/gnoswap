package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// TestNewDelegationManagerResolver tests the creation of DelegationManagerResolver
func TestNewDelegationManagerResolver(t *testing.T) {
	t.Run("Create new delegation manager resolver", func(t *testing.T) {
		// given
		manager := staker.NewDelegationManager()

		// when
		resolver := NewDelegationManagerResolver(manager)

		// then
		uassert.NotNil(t, resolver)
		uassert.NotNil(t, resolver.DelegationManager)
	})
}

// TestDelegationManagerResolver_GetUserDelegationIDsWithDelegatee tests retrieving delegation IDs for specific pair
func TestDelegationManagerResolver_GetUserDelegationIDsWithDelegatee(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(*DelegationManagerResolver)
		delegator        address
		delegatee        address
		expectedIDsCount int
	}{
		{
			name: "Get delegation IDs for existing pair",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 2)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			expectedIDsCount: 2,
		},
		{
			name:             "Get delegation IDs for non-existent pair",
			setup:            func(dm *DelegationManagerResolver) {},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			expectedIDsCount: 0,
		},
		{
			name: "Get delegation IDs for one delegatee among multiple",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee1"), 1)
				dm.addDelegation(address("g1delegator"), address("g1delegatee1"), 2)
				dm.addDelegation(address("g1delegator"), address("g1delegatee2"), 3)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee1"),
			expectedIDsCount: 2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := staker.NewDelegationManager()
			resolver := NewDelegationManagerResolver(manager)
			tc.setup(resolver)

			// when
			ids := resolver.GetUserDelegationIDsWithDelegatee(tc.delegator, tc.delegatee)

			// then
			uassert.Equal(t, len(ids), tc.expectedIDsCount)
		})
	}
}

// TestDelegationManagerResolver_GetUserDelegationIDs tests retrieving all delegation IDs for a delegator
func TestDelegationManagerResolver_GetUserDelegationIDs(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(*DelegationManagerResolver)
		delegator        address
		expectedIDsCount int
	}{
		{
			name: "Get all delegation IDs for delegator with multiple delegatees",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee1"), 1)
				dm.addDelegation(address("g1delegator"), address("g1delegatee1"), 2)
				dm.addDelegation(address("g1delegator"), address("g1delegatee2"), 3)
				dm.addDelegation(address("g1delegator"), address("g1delegatee3"), 4)
			},
			delegator:        address("g1delegator"),
			expectedIDsCount: 4,
		},
		{
			name:             "Get delegation IDs for delegator with no delegations",
			setup:            func(dm *DelegationManagerResolver) {},
			delegator:        address("g1delegator"),
			expectedIDsCount: 0,
		},
		{
			name: "Get delegation IDs for one delegator among multiple",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator1"), address("g1delegatee"), 1)
				dm.addDelegation(address("g1delegator1"), address("g1delegatee"), 2)
				dm.addDelegation(address("g1delegator2"), address("g1delegatee"), 3)
			},
			delegator:        address("g1delegator1"),
			expectedIDsCount: 2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := staker.NewDelegationManager()
			resolver := NewDelegationManagerResolver(manager)
			tc.setup(resolver)

			// when
			ids := resolver.GetUserDelegationIDs(tc.delegator)

			// then
			uassert.Equal(t, len(ids), tc.expectedIDsCount)
		})
	}

	t.Run("Get delegation IDs with multiple delegatees and verify per-delegatee counts", func(t *testing.T) {
		// given
		manager := staker.NewDelegationManager()
		resolver := NewDelegationManagerResolver(manager)
		delegator := address("g1delegator")

		// when - add delegations to multiple delegatees
		resolver.addDelegation(delegator, address("g1delegatee1"), 1)
		resolver.addDelegation(delegator, address("g1delegatee1"), 2)
		resolver.addDelegation(delegator, address("g1delegatee2"), 3)
		resolver.addDelegation(delegator, address("g1delegatee3"), 4)
		resolver.addDelegation(delegator, address("g1delegatee3"), 5)

		// then - should get all IDs
		allIds := resolver.GetUserDelegationIDs(delegator)
		uassert.Equal(t, len(allIds), 5)

		// And specific delegatee IDs
		ids1 := resolver.GetUserDelegationIDsWithDelegatee(delegator, address("g1delegatee1"))
		uassert.Equal(t, len(ids1), 2)

		ids2 := resolver.GetUserDelegationIDsWithDelegatee(delegator, address("g1delegatee2"))
		uassert.Equal(t, len(ids2), 1)

		ids3 := resolver.GetUserDelegationIDsWithDelegatee(delegator, address("g1delegatee3"))
		uassert.Equal(t, len(ids3), 2)
	})
}

// TestDelegationManagerResolver_addDelegation tests adding delegations
func TestDelegationManagerResolver_addDelegation(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(*DelegationManagerResolver)
		delegator        address
		delegatee        address
		delegationID     int64
		expectedIDsCount int
	}{
		{
			name:             "Add first delegation",
			setup:            func(dm *DelegationManagerResolver) {},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     1,
			expectedIDsCount: 1,
		},
		{
			name: "Add second delegation to same pair",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     2,
			expectedIDsCount: 2,
		},
		{
			name: "Add duplicate delegation ID (should not add)",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     1,
			expectedIDsCount: 1, // Should remain 1
		},
		{
			name: "Add delegation to different delegatee",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee1"), 1)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee2"),
			delegationID:     2,
			expectedIDsCount: 1, // Only 1 for this specific delegatee
		},
		{
			name:             "Add delegation with zero ID",
			setup:            func(dm *DelegationManagerResolver) {},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     0,
			expectedIDsCount: 1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := staker.NewDelegationManager()
			resolver := NewDelegationManagerResolver(manager)
			tc.setup(resolver)

			// when
			resolver.addDelegation(tc.delegator, tc.delegatee, tc.delegationID)

			// then
			ids := resolver.GetUserDelegationIDsWithDelegatee(tc.delegator, tc.delegatee)
			uassert.Equal(t, len(ids), tc.expectedIDsCount)
		})
	}
}

// TestDelegationManagerResolver_removeDelegation tests removing delegations
func TestDelegationManagerResolver_removeDelegation(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(*DelegationManagerResolver)
		delegator        address
		delegatee        address
		delegationID     int64
		expectedIDsCount int
	}{
		{
			name: "Remove existing delegation",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 2)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     1,
			expectedIDsCount: 1, // Should have 1 remaining
		},
		{
			name: "Remove non-existent delegation",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     999, // Non-existent ID
			expectedIDsCount: 1,   // Should remain unchanged
		},
		{
			name:             "Remove from non-existent pair",
			setup:            func(dm *DelegationManagerResolver) {},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     1,
			expectedIDsCount: 0,
		},
		{
			name: "Remove last delegation",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     1,
			expectedIDsCount: 0, // Should be empty
		},
		{
			name: "Remove middle delegation from list",
			setup: func(dm *DelegationManagerResolver) {
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 1)
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 2)
				dm.addDelegation(address("g1delegator"), address("g1delegatee"), 3)
			},
			delegator:        address("g1delegator"),
			delegatee:        address("g1delegatee"),
			delegationID:     2,
			expectedIDsCount: 2, // Should have 2 remaining (1 and 3)
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := staker.NewDelegationManager()
			resolver := NewDelegationManagerResolver(manager)
			tc.setup(resolver)

			// when
			resolver.removeDelegation(tc.delegator, tc.delegatee, tc.delegationID)

			// then
			ids := resolver.GetUserDelegationIDsWithDelegatee(tc.delegator, tc.delegatee)
			uassert.Equal(t, len(ids), tc.expectedIDsCount)
		})
	}

	t.Run("Remove all delegations sequentially", func(t *testing.T) {
		// given
		manager := staker.NewDelegationManager()
		resolver := NewDelegationManagerResolver(manager)
		delegator := address("g1delegator")
		delegatee := address("g1delegatee")

		// when - add multiple then remove all
		resolver.addDelegation(delegator, delegatee, 1)
		resolver.addDelegation(delegator, delegatee, 2)
		resolver.addDelegation(delegator, delegatee, 3)

		resolver.removeDelegation(delegator, delegatee, 1)
		resolver.removeDelegation(delegator, delegatee, 2)
		resolver.removeDelegation(delegator, delegatee, 3)

		// then - should be empty
		ids := resolver.GetUserDelegationIDsWithDelegatee(delegator, delegatee)
		uassert.Equal(t, len(ids), 0)
	})
}
