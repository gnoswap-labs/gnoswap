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
func cloneProposalEntry(value any) any {
	proposal, ok := value.(*governance.Proposal)
	if !ok {
		return nil
	}

	return proposal.Clone()
}

// cloneVotingInfoEntry is the transformation for a proposal's voting info
// tree. VotingInfo is mutable and its setters are declared in
// /r/gnoswap/gov/governance, so an external holder of the stored pointer could
// write realm state through it.
func cloneVotingInfoEntry(value any) any {
	votingInfo, ok := value.(*governance.VotingInfo)
	if !ok {
		return nil
	}

	return votingInfo.Clone()
}

// cloneProposalIDsEntry is the transformation for the user proposal tree. The
// stored value is a slice, so hand out a copy rather than letting a reader
// write through the shared backing array.
func cloneProposalIDsEntry(value any) any {
	proposalIDs, ok := value.([]int64)
	if !ok {
		return nil
	}

	cloned := make([]int64, len(proposalIDs))
	copy(cloned, proposalIDs)

	return cloned
}
