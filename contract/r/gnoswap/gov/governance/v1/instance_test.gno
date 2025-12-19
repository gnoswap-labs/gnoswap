package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestInstance_NewGovernanceV1 tests the creation of governance v1 instance
func TestInstance_NewGovernanceV1(t *testing.T) {
	// given
	store := createMockGovernanceStore()

	// when
	impl := NewGovernanceV1(store, newMockGovStakerAccessor())

	// then
	uassert.NotNil(t, impl)

	// Verify it implements IGovernance interface
	_, ok := impl.(governance.IGovernance)
	uassert.True(t, ok)

	// Verify internal structure by type assertion
	gv, ok := impl.(*governanceV1)
	uassert.True(t, ok)
	uassert.NotNil(t, gv.store)

	// Verify store methods are accessible
	counter := gv.store.GetProposalCounter()
	uassert.NotNil(t, counter)
}
