package v1

import (
	"chain"
	"chain/runtime"

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

	removed, checkpointed := compactHistoryAtCutoff(history, cutoffTimestamp)
	if removed > 0 && !checkpointed {
		panic("cleanTotalDelegationHistory: entries removed without checkpoint")
	}

	if err := gs.store.SetTotalDelegationHistory(history); err != nil {
		panic(err)
	}
}

// cleanUserDelegationHistory removes user delegation history entries older than cutoff time.
// Structure: address -> *UintTree[timestamp -> int64]
// Keeps the most recent entry before cutoff for each user to preserve state continuity.
func (gs *govStakerV1) cleanUserDelegationHistory(cutoffTimestamp int64) {
	history := gs.store.GetUserDelegationHistory()

	toRemove := make([]string, 0)
	history.Iterate("", "", func(addrStr string, value any) bool {
		userHistory := value.(*staker.UintTree)

		removed, checkpointed := compactHistoryAtCutoff(userHistory, cutoffTimestamp)
		if removed > 0 && !checkpointed {
			panic("cleanUserDelegationHistory: entries removed without checkpoint")
		}

		if userHistory.Size() == 0 {
			toRemove = append(toRemove, addrStr)
		}

		return false
	})

	for _, addrStr := range toRemove {
		history.Remove(addrStr)
	}

	if err := gs.store.SetUserDelegationHistory(history); err != nil {
		panic(err)
	}
}

// compactHistoryAtCutoff folds every entry in [0, cutoff) into a single entry at cutoff,
// carrying forward the most recent value so state continuity is preserved across the prune.
// Entries at or after cutoff are left untouched.
//
// Returns the number of entries removed and whether a checkpoint was written at cutoff,
// so callers can explicitly verify the postcondition.
//
// Note: bptree forbids Set/Remove during Iterate (leaf slice shifts skip entries),
// so keys to remove are collected first and deleted in a separate pass. (See: btree/nt/v0/tree.go:Iterate)
func compactHistoryAtCutoff(tree *staker.UintTree, cutoff int64) (removed int, checkpointed bool) {
	var lastValue any

	tree.ReverseIterate(0, cutoff, func(_ int64, value any) bool {
		lastValue = value
		checkpointed = true
		return true
	})

	if checkpointed {
		tree.Set(cutoff, lastValue)
	}

	toRemove := make([]int64, 0)
	tree.Iterate(0, cutoff, func(key int64, _ any) bool {
		toRemove = append(toRemove, key)
		return false
	})

	for _, key := range toRemove {
		tree.Remove(key)
	}

	return len(toRemove), checkpointed
}
