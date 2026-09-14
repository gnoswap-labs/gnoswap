package governance

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

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
