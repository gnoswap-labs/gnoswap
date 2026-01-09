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
			ids, _ := resolver.GetDelegationIDs(tc.delegator.String(), tc.delegatee.String())
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
			ids, _ := resolver.GetDelegationIDs(tc.delegator.String(), tc.delegatee.String())
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
		ids, _ := resolver.GetDelegationIDs(delegator.String(), delegatee.String())
		uassert.Equal(t, len(ids), 0)
	})
}
