package staker

import (
	sr "gno.land/r/gnoswap/staker"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// cloneExternalIncentiveEntry is the transformation for a pool's incentive
// tree. ExternalIncentive is mutable and its setters are declared in
// /r/gnoswap/staker, so an external holder of the stored pointer could write
// realm state through it.
func cloneExternalIncentiveEntry(value any) any {
	incentive, ok := value.(*sr.ExternalIncentive)
	if !ok {
		return nil
	}

	return incentive.Clone()
}
