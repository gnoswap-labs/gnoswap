package v1

import (
	"chain"
	"chain/runtime"
	"math"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gov/staker"
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
//
// Panics:
//   - if caller is not admin
//   - if snapshotTime is invalid (negative or too recent)
//   - if active proposals have snapshotTime older than the cleanup threshold
//
// Note: This operation is irreversible and will permanently remove historical data
func (gs *govStakerV1) CleanStakerDelegationSnapshotByAdmin(snapshotTime int64) {
	halt.AssertIsNotHaltedGovStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdmin(caller)

	assertIsValidSnapshotTime(snapshotTime)
	assertIsAvailableCleanupSnapshotTime(snapshotTime)

	// Clean total delegation history
	gs.cleanTotalDelegationHistory(snapshotTime)

	// Clean user delegation history
	gs.cleanUserDelegationHistory(snapshotTime)

	chain.Emit(
		"CleanStakerDelegationSnapshot",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"snapshotTime", formatInt(snapshotTime),
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
	if hasLastValue {
		history.Set(cutoffTimestamp, lastValue)
	}

	history.Iterate(0, cutoffTimestamp, func(timestamp int64, _ any) bool {
		history.Remove(timestamp)

		return false // continue
	})

	if err := gs.store.SetTotalDelegationHistory(history); err != nil {
		panic(err)
	}
}

// cleanUserDelegationHistory removes user delegation history entries older than cutoff time.
// Structure: address -> *UintTree[timestamp -> int64]
// Keeps the most recent entry before cutoff for each user to preserve state continuity.
func (gs *govStakerV1) cleanUserDelegationHistory(cutoffTimestamp int64) {
	history := gs.store.GetUserDelegationHistory()

	// Iterate over all users and clean each user's history
	history.Iterate("", "", func(addrStr string, value any) bool {
		userHistory := value.(*staker.UintTree)

		toTimestamp := cutoffTimestamp
		if cutoffTimestamp < math.MaxInt64 {
			toTimestamp = safeAddInt64(toTimestamp, 1)
		}

		// Find the most recent entry before cutoff to preserve state
		var lastValue any

		hasLastValue := false

		userHistory.ReverseIterate(0, toTimestamp, func(_ int64, val any) bool {
			lastValue = val
			hasLastValue = true

			return true // stop after first (most recent)
		})

		// If there was a value before cutoff, set it at cutoff time to preserve continuity
		if hasLastValue {
			userHistory.Set(cutoffTimestamp, lastValue)
		}

		// Copy all entries at or after cutoff time
		userHistory.Iterate(0, cutoffTimestamp, func(key int64, val any) bool {
			userHistory.Remove(key)

			return false // continue
		})

		// Only keep users with history entries
		if userHistory.Size() > 0 {
			history.Set(addrStr, userHistory)
		}

		return false // continue to next user
	})

	if err := gs.store.SetUserDelegationHistory(history); err != nil {
		panic(err)
	}
}
