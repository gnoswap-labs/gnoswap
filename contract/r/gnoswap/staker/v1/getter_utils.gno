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

// rewardCacheEntry, accumulationEntry, and historicalTickEntry are the
// transformations for the UintTree-backed views. Their values are immutable
// scalars, so nothing needs copying; they type-check instead, which keeps the
// filtering the replaced slice getters did when an entry failed its cast.
func rewardCacheEntry(value any) any {
	reward, ok := value.(int64)
	if !ok {
		return nil
	}

	return reward
}

func accumulationEntry(value any) any {
	accumulation, ok := value.(string)
	if !ok {
		return nil
	}

	return accumulation
}

func historicalTickEntry(value any) any {
	tick, ok := value.(int32)
	if !ok {
		return nil
	}

	return tick
}
