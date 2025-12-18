package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/avl"
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

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if period < 0 {
		panic("period must be greater than 0")
	}

	gs.setUnDelegationLockupPeriod(period)

	previousRealm := runtime.PreviousRealm()
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
// 1. Calculates cutoff time by subtracting threshold from current time
// 2. Filters delegation history to keep only records after cutoff time
// 3. Updates the delegation history with filtered records
//
// Parameters:
//   - threshold: time threshold in seconds (records older than this will be removed)
//
// Panics:
//   - if caller is not admin
//
// Note: This operation is irreversible and will permanently remove historical data
func (gs *govStakerV1) CleanStakerDelegationSnapshotByAdmin(snapshotTime int64) {
	halt.AssertIsNotHaltedGovStaker()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// Clean total delegation history
	gs.cleanTotalDelegationHistory(snapshotTime)

	// Clean user delegation history
	gs.cleanUserDelegationHistory(snapshotTime)
}

// cleanTotalDelegationHistory removes total delegation history entries older than cutoff time.
// Keeps the most recent entry before cutoff to preserve state continuity.
func (gs *govStakerV1) cleanTotalDelegationHistory(cutoffTimestamp int64) {
	history := gs.store.GetTotalDelegationHistory()
	newHistory := staker.NewUintTree()

	// First, find the most recent entry before cutoff to preserve state
	var lastBeforeCutoff int64
	var lastValueBeforeCutoff any

	foundBeforeCutoff := false

	history.ReverseIterate(0, cutoffTimestamp, func(key int64, value any) bool {
		lastBeforeCutoff = key
		lastValueBeforeCutoff = value
		foundBeforeCutoff = true

		return true // stop after first (most recent)
	})

	// If there was a value before cutoff, set it at cutoff time to preserve continuity
	if foundBeforeCutoff {
		newHistory.Set(cutoffTimestamp, lastValueBeforeCutoff)
	}

	// Copy all entries at or after cutoff time
	history.Iterate(cutoffTimestamp, int64(^uint64(0)>>1), func(key int64, value any) bool {
		if key > lastBeforeCutoff { // Don't duplicate if we already added the cutoff entry
			newHistory.Set(key, value)
		}
		return false // continue
	})

	if err := gs.store.SetTotalDelegationHistory(newHistory); err != nil {
		panic(err)
	}
}

// cleanUserDelegationHistory removes user delegation history entries older than cutoff time.
// Structure: address -> *UintTree[timestamp -> int64]
// Keeps the most recent entry before cutoff for each user to preserve state continuity.
func (gs *govStakerV1) cleanUserDelegationHistory(cutoffTimestamp int64) {
	history := gs.store.GetUserDelegationHistory()
	newHistory := avl.NewTree()

	// Iterate over all users and clean each user's history
	history.Iterate("", "", func(addrStr string, value any) bool {
		userHistory := value.(*staker.UintTree)
		newUserHistory := staker.NewUintTree()

		// Find the most recent entry before cutoff to preserve state
		var lastBeforeCutoff int64
		var lastValueBeforeCutoff any

		foundBeforeCutoff := false

		userHistory.ReverseIterate(0, cutoffTimestamp, func(key int64, val any) bool {
			lastBeforeCutoff = key
			lastValueBeforeCutoff = val
			foundBeforeCutoff = true

			return true // stop after first (most recent)
		})

		// If there was a value before cutoff, set it at cutoff time to preserve continuity
		if foundBeforeCutoff {
			newUserHistory.Set(cutoffTimestamp, lastValueBeforeCutoff)
		}

		// Copy all entries at or after cutoff time
		userHistory.Iterate(cutoffTimestamp, int64(^uint64(0)>>1), func(key int64, val any) bool {
			if key > lastBeforeCutoff { // Don't duplicate if we already added the cutoff entry
				newUserHistory.Set(key, val)
			}

			return false // continue
		})

		// Only keep users with history entries
		if newUserHistory.Size() > 0 {
			newHistory.Set(addrStr, newUserHistory)
		}

		return false // continue to next user
	})

	if err := gs.store.SetUserDelegationHistory(newHistory); err != nil {
		panic(err)
	}
}
