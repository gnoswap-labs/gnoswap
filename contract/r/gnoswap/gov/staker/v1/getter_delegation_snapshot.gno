package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

func (gs *govStakerV1) HasDelegationSnapshotsKey() bool {
	return gs.store.HasDelegationSnapshotStoreKey()
}

// GetDelegationSnapshots retrieves the delegation snapshot at a specific point in time.
// This function reconstructs historical delegation states by taking the current snapshot
// and reversing the effects of delegation records that occurred after the specified time.
//
// The algorithm works by:
// 1. Cloning the current delegation snapshot
// 2. Getting all delegation records that occurred at or after the snapshot time
// 3. Subtracting each record in reverse chronological order to restore the historical state
//
// Parameters:
//   - snapshotTime: timestamp to retrieve the snapshot for
//
// Returns:
//   - DelegationSnapshot: delegation state at the specified time
//   - bool: true if snapshot was successfully calculated, false otherwise
func (gs *govStakerV1) GetDelegationSnapshots(snapshotTime int64) (staker.DelegationSnapshot, bool) {
	// Get current delegation snapshots and create a working copy
	delegationSnapshots := gs.getDelegationSnapshots()
	resolver := NewDelegationSnapshotResolver(delegationSnapshots)
	currentDelegationSnapshot := resolver.Clone()

	// Get delegation history and filter for records after snapshot time
	delegationHistory := gs.getDelegationHistory()
	historyResolver := NewDelegationHistoryResolver(delegationHistory)
	historyRecords := historyResolver.getRecordsBy(snapshotTime)

	// Apply records in reverse order to reconstruct historical state
	for i := len(historyRecords) - 1; i >= 0; i-- {
		currentResolver := NewDelegationSnapshotResolver(currentDelegationSnapshot)
		currentDelegationSnapshot = currentResolver.SubRecord(historyRecords[i])
	}

	// Convert internal DelegationSnapshot to staker.DelegationSnapshot
	result := make(staker.DelegationSnapshot)
	for delegatee, item := range currentDelegationSnapshot {
		result[delegatee] = staker.NewDelegationSnapshotItem(item.DelegationAmount(), item.DelegatorAddress())
	}

	return result, true
}
