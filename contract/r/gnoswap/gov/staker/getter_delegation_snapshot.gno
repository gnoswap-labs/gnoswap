package staker

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
func GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool) {
	// Get current delegation snapshots and create a working copy
	delegationSnapshots := getDelegationSnapshots()
	currentDelegationSnapshot := delegationSnapshots.clone()

	// Get delegation history and filter for records after snapshot time
	delegationHistory := getDelegationHistory()
	historyRecords := delegationHistory.getRecordsBy(snapshotTime)

	// Apply records in reverse order to reconstruct historical state
	// This effectively "undoes" all delegation changes that happened after snapshotTime
	for i := len(historyRecords) - 1; i >= 0; i-- {
		currentDelegationSnapshot = currentDelegationSnapshot.subRecord(historyRecords[i])
	}

	return currentDelegationSnapshot, true
}
