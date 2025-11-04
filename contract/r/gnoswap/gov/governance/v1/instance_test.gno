package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestInstance_NewGovernanceV1 tests the creation of governance v1 instance
func TestInstance_NewGovernanceV1(t *testing.T) {
	tests := []struct {
		name  string
		setup func() governance.IGovernanceStore
	}{
		{
			name: "create with valid governance store",
			setup: func() governance.IGovernanceStore {
				return createMockGovernanceStore()
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			store := tt.setup()

			// when
			impl := NewGovernanceV1(store)

			// then
			uassert.NotNil(t, impl)

			// Verify it implements IGovernance interface
			_, ok := impl.(governance.IGovernance)
			uassert.True(t, ok)

			// Verify internal structure by type assertion
			gv, ok := impl.(*governanceV1)
			uassert.True(t, ok)
			uassert.NotNil(t, gv.store)
			uassert.NotNil(t, gv.getUserVotingInfoSnapshotFn)
		})
	}
}

// TestInstance_DefaultVotingSnapshotFunction tests the default voting snapshot function
func TestInstance_DefaultVotingSnapshotFunction(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "verify default voting snapshot function is set",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			store := createMockGovernanceStore()

			// when
			impl := NewGovernanceV1(store)

			// then
			gv, ok := impl.(*governanceV1)
			uassert.True(t, ok)

			// Verify the snapshot function is not nil
			uassert.NotNil(t, gv.getUserVotingInfoSnapshotFn)
		})
	}
}

// TestInstance_StoreAccess tests that the instance can access the store
func TestInstance_StoreAccess(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "verify store is accessible through instance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			store := createMockGovernanceStore()

			// when
			impl := NewGovernanceV1(store)

			// then
			gv, ok := impl.(*governanceV1)
			uassert.True(t, ok)
			uassert.NotNil(t, gv.store)

			// Verify store methods are accessible
			counter := gv.store.GetProposalCounter()
			uassert.NotNil(t, counter)
		})
	}
}
