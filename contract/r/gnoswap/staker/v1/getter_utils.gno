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
//
// Parameters:
//   - value: Tree value expected to be an *sr.ExternalIncentive.
//
// Returns:
//   - any: A deep clone of the incentive when value has the expected type; nil for another type.
func cloneExternalIncentiveEntry(value any) any {
	incentive, ok := value.(*sr.ExternalIncentive)
	if !ok {
		return nil
	}

	return incentive.Clone()
}

// rewardCacheEntry, accumulationEntry, and historicalTickEntry are the
// transformations for the UintTree-backed views. Their values are immutable
// scalars, so nothing needs copying; they type-check instead, which keeps the
// filtering the replaced slice getters did when an entry failed its cast.
//
// Parameters:
//   - value: Tree value expected to be an int64 reward amount.
//
// Returns:
//   - any: The int64 reward amount unchanged, or nil when value has another type.
func rewardCacheEntry(value any) any {
	reward, ok := value.(int64)
	if !ok {
		return nil
	}

	return reward
}

// accumulationEntry converts a tree value to the immutable string form used by read-only accumulation views.
//
// Parameters:
//   - value: Tree value expected to be a string-encoded global reward-ratio accumulation.
//
// Returns:
//   - any: The accumulation string unchanged, or nil when value has another type.
func accumulationEntry(value any) any {
	accumulation, ok := value.(string)
	if !ok {
		return nil
	}

	return accumulation
}

// historicalTickEntry converts a tree value to the immutable int32 form used by read-only historical-tick views.
//
// Parameters:
//   - value: Tree value expected to be an int32 historical tick.
//
// Returns:
//   - any: The historical tick unchanged, or nil when value has another type.
func historicalTickEntry(value any) any {
	tick, ok := value.(int32)
	if !ok {
		return nil
	}

	return tick
}
