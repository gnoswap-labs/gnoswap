package staker

import (
	"gno.land/r/gnoswap/gov/staker"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// cloneDelegationEntry is the transformation for the delegation tree.
// Delegation records are stored as values; accept the legacy pointer form so
// reads remain compatible with pre-migration state and test fixtures.
func cloneDelegationEntry(value any) any {
	switch delegation := value.(type) {
	case staker.Delegation:
		return (&delegation).Clone()
	case *staker.Delegation:
		return delegation.Clone()
	default:
		return nil
	}
}

// cloneDelegationIDsEntry is the transformation for a delegator's delegation
// tree. The stored value is a slice, so hand out a copy rather than letting a
// reader write through the shared backing array.
func cloneDelegationIDsEntry(value any) any {
	delegationIDs, ok := value.([]int64)
	if !ok {
		return nil
	}

	cloned := make([]int64, len(delegationIDs))
	copy(cloned, delegationIDs)

	return cloned
}
