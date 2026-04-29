package v1

import (
	"chain"
	"chain/runtime"
	"math"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// This administrative function configures the time period that undelegated tokens
// must wait before they can be collected by users.
//
// The lockup period serves as a security mechanism to:
// - Prevent rapid delegation/undelegation cycles
// - Provide time for governance decisions to take effect
// - Maintain system stability during volatile periods
//
// Parameters:
//   - period: lockup period in seconds (must be non-negative)
//
// Panics:
//   - if caller is not admin
//   - if period is negative
//
// Note: This change affects all future undelegation operations
func (gs *govStakerV1) SetUnDelegationLockupPeriodByAdmin(period int64) {
	halt.AssertIsNotHaltedGovStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdmin(caller)

	if period < 0 {
		panic("period must be greater than 0")
	}

	gs.setUnDelegationLockupPeriod(period)

	chain.Emit(
		"SetUnDelegationLockupPeriod",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"period", formatInt(period),
	)
}

// CleanStakerDelegationSnapshotByAdmin cleans old delegation history records.
// This administrative function removes delegation history records older than the specified threshold
// to prevent unlimited growth of historical data and optimize storage usage.
//
// The cleanup process:
// 1. Validates the snapshot time is within allowed range
// 2. Checks that no active proposals need data older than the cleanup threshold
// 3. Filters delegation history to keep only records after cutoff time
// 4. Updates the delegation history with filtered records
//
// Parameters:
//   - snapshotTime: cutoff timestamp (records older than this will be removed)
//   - target: the user address whose delegation history should be cleaned
//
// Panics:
//   - if caller is not admin
//   - if snapshotTime is invalid (negative or too recent)
//   - if active proposals have snapshotTime older than the cleanup threshold
func (gs *govStakerV1) CleanStakerDelegationSnapshotByAdmin(snapshotTime int64, target address) {
	halt.AssertIsNotHaltedGovStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdmin(caller)

	assertIsValidSnapshotTime(snapshotTime)
	assertIsAvailableCleanupSnapshotTime(snapshotTime)

	// Clean total delegation history
	gs.cleanTotalDelegationHistory(snapshotTime)

	// Clean user delegation history
	gs.cleanUserDelegationHistoryForAddress(target, snapshotTime)

	chain.Emit(
		"CleanStakerDelegationSnapshot",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"snapshotTime", formatInt(snapshotTime),
		"target", target.String(),
	)
}

// cleanTotalDelegationHistory removes total delegation history entries older than cutoff time.
// Keeps the most recent entry before cutoff to preserve state continuity.
func (gs *govStakerV1) cleanTotalDelegationHistory(cutoffTimestamp int64) {
	history := gs.store.GetTotalDelegationHistory()

	toTimestamp := cutoffTimestamp
	if cutoffTimestamp < math.MaxInt64 {
		toTimestamp = safeAddInt64(toTimestamp, 1)
	}

	// First, find the most recent entry before cutoff to preserve state
	var lastValue any

	hasLastValue := false

	history.ReverseIterate(0, toTimestamp, func(timestamp int64, value any) bool {
		lastValue = value
		hasLastValue = true

		return true // stop after first (most recent)
	})

	// If there was a value before cutoff, set it at cutoff time to preserve continuity
	if hasLastValue && !history.Has(cutoffTimestamp) {
		history.Set(cutoffTimestamp, lastValue)
	}

	// Collect keys to remove (cannot modify tree during iteration)
	var keysToRemove []int64
	history.Iterate(0, cutoffTimestamp, func(timestamp int64, _ any) bool {
		keysToRemove = append(keysToRemove, timestamp)
		return false // continue
	})
	for _, key := range keysToRemove {
		history.Remove(key)
	}

	if err := gs.store.SetTotalDelegationHistory(history); err != nil {
		panic(err)
	}
}

// cleanUserDelegationHistoryForAddress removes user delegation history entries
// older than cutoff time for a single target address.
// Keeps the most recent entry strictly before cutoff
// in place so range-based snapshot lookups continue to resolve correctly.
func (gs *govStakerV1) cleanUserDelegationHistoryForAddress(target address, cutoffTimestamp int64) {
	if cutoffTimestamp <= 0 {
		return
	}

	toTimestamp := cutoffTimestamp
	if cutoffTimestamp < math.MaxInt64 {
		toTimestamp = safeAddInt64(toTimestamp, 1)
	}

	history := gs.store.GetUserDelegationHistory()

	addrStr := target.String()
	iterationStartKey, _ := userHistoryKeyRange(addrStr)
	iterationEndKey := makeUserHistoryKey(addrStr, toTimestamp)
	cutoffKey := makeUserHistoryKey(addrStr, cutoffTimestamp)

	// First, find the most recent entry before cutoff to preserve state
	var lastValue any

	hasLastValue := false

	history.ReverseIterate(iterationStartKey, iterationEndKey, func(key string, value any) bool {
		lastValue = value
		hasLastValue = true

		return true // stop after first (most recent)
	})

	if hasLastValue && !history.Has(cutoffKey) {
		history.Set(cutoffKey, lastValue)
	}

	// Collect all keys strictly before preserveKey within this address prefix.
	// Iterate's end is exclusive, so [lo, preserveKey) skips the preserved entry.
	var keysToRemove []string

	history.Iterate(iterationStartKey, cutoffKey, func(key string, _ any) bool {
		keysToRemove = append(keysToRemove, key)

		return false
	})

	for _, key := range keysToRemove {
		history.Remove(key)
	}

	if err := gs.store.SetUserDelegationHistory(history); err != nil {
		panic(err)
	}
}
