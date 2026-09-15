package governance

import (
	"gno.land/r/gnoswap/gov/governance"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// cloneProposalEntry is the transformation for the proposal tree. Proposal is
// mutable and its setters are declared in /r/gnoswap/gov/governance, so an
// external holder of the stored pointer could write realm state through it.
//
// Proposal.Clone leaves the type-specific data nil; see it for which lookups
// read it instead.
// cloneProposalEntry clones a stored proposal before exposing it through a read-only tree.
// Values of other types are rejected with a nil result.
//
// Parameters:
//   - value: stored tree value expected to be a *governance.Proposal.
//
// Returns:
//   - any: deep-cloned proposal, or nil when value is not a proposal pointer.
func cloneProposalEntry(value any) any {
	proposal, ok := value.(*governance.Proposal)
	if !ok {
		return nil
	}

	return proposal.Clone()
}

// cloneProposalIDsEntry is the transformation for the user proposal tree. The
// stored value is a slice, so hand out a copy rather than letting a reader
// write through the shared backing array.
// Values of other types are rejected with a nil result.
//
// Parameters:
//   - value: stored tree value expected to be a []int64 of proposal IDs.
//
// Returns:
//   - any: copied []int64 slice, or nil when value is not a proposal-ID slice.
func cloneProposalIDsEntry(value any) any {
	proposalIDs, ok := value.([]int64)
	if !ok {
		return nil
	}

	cloned := make([]int64, len(proposalIDs))
	copy(cloned, proposalIDs)

	return cloned
}
