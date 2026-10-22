package staker

import (
	"gno.land/r/gnoswap/gov/staker"
)

// cloneDelegationEntry is the transformation for the delegation tree.
// Delegation is mutable and its setters are declared in /r/gnoswap/gov/staker,
// so an external holder of the stored pointer could write realm state through
// it.
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
func cloneDelegationIDsEntry(value any) any {
	delegationIDs, ok := value.([]int64)
	if !ok {
		return nil
	}

	cloned := make([]int64, len(delegationIDs))
	copy(cloned, delegationIDs)

	return cloned
}
