package staker

import (
	"gno.land/r/gnoswap/gov/staker"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.
//
// cloneDelegationEntry is the transformation for the delegation tree.
// Delegation is mutable and its setters are declared in /r/gnoswap/gov/staker,
// so an external holder of the stored pointer could write realm state through
// it.
// Parameters:
//   - value: Tree entry expected to contain a *staker.Delegation.
//
// Returns:
//   - any: cloned *staker.Delegation when value has that type; nil for another type or nil value.
func cloneDelegationEntry(value any) any {
	delegation, ok := value.(*staker.Delegation)
	if !ok {
		return nil
	}

	return delegation.Clone()
}

// cloneDelegationIDsEntry is the transformation for a delegator's delegation
// tree. The stored value is a slice, so hand out a copy rather than letting a
// reader write through the shared backing array.
// Parameters:
//   - value: Tree entry expected to contain a []int64 delegation-ID slice.
//
// Returns:
//   - any: copied []int64 slice when value has that type; nil for another type or nil value.
func cloneDelegationIDsEntry(value any) any {
	delegationIDs, ok := value.([]int64)
	if !ok {
		return nil
	}

	cloned := make([]int64, len(delegationIDs))
	copy(cloned, delegationIDs)

	return cloned
}
